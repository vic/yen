let
  # the stage of a change of this page's fleet, as `stage.nix` runs it
  stageOf =
    inputs: dir: change:
    import (dir + "/stage.nix") {
      yen = inputs.yen.outPath;
      inherit (inputs) nixpkgs import-tree;
      change = "changes/${change}.json";
    };
  # what an agent sees of a refused change: whether it may land, and the rules it breaks
  answerOf =
    inputs: dir: change:
    let
      s = stageOf inputs dir change;
    in
    {
      inherit (s) ok violations;
      errors = map (e: e.code) s.errors;
    };
in
{
  title = "Guardrails for agents";
  description = "Rules for the mistakes that take fleets down: a copied IP, a taken port, a database on the internet, no backup, a production token in dev. An agent's change is refused before any file is written.";
  section = "agents";
  order = 3;

  body =
    {
      docs,
      inputs,
      dir,
      ...
    }:
    [
      ''
        Fleets do not fail in exotic ways. People who run Proxmox clusters, Kubernetes clusters and homelabs hit the same
        mistakes again and again, on machines they do not look at that day:

        - **A copied address.** A cloned [Proxmox VM comes up with the IP of its original](https://forum.proxmox.com/threads/ip-address-duplicates-conflicts-when-cloning-from-a-template.84237/),
          and [a duplicate VMID breaks backups](https://forum.proxmox.com/threads/backup-vm-with-duplicate-vm-ids-on-single-datastore.152027/).
        - **A port taken twice**, or a [Service whose port does not match the container's](https://www.aurorasre.ai/runbooks/fix-service-targetport-mismatch-kubernetes):
          the endpoints exist and connections are refused.
        - **Something on the internet that should not be.** [A namespace with no network policy allows all traffic, and a NodePort
          is open on every node](https://lukasniessen.github.io/kubernetes-skill/failure-modes/network-exposure.html). Red Hat's
          [State of Kubernetes Security](https://www.redhat.com/tracks/_pfcdn/assets/10330/contents/646381/001b54d3-7c21-417b-995c-ebe7be8328a1.pdf)
          report found a misconfiguration to be the leading cause of incidents in 2023 (59%).
        - **A backup that is not there.** [GitLab's 2017 database outage](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/):
          every backup method had failed without anyone noticing.
        - **A credential in the wrong place.** In 2026 [an agent working on staging found a production API token in an unrelated file and used
          it](https://adversa.ai/blog/ai-coding-agent-incidents/). The backups were in the volume it deleted.

        An agent makes these mistakes faster than a person, and a rule in a prompt ("do not touch production") does not stop it.
        A rule in the fleet does. This fleet has three machines in two zones and the services on them:
      ''
      (docs.file "modules/fleet.nix")
      ''
        Each rule below is one of those mistakes, written once. A rule holds across every machine, and a fleet that breaks one is not built.
      ''
      (docs.file "modules/invariants.nix")
      ''
        ## An agent proposes a change

        A change is data. [Stage it](/agents/stage/) and the fleet is evaluated with the change, and nothing is written. The agent gets the
        answer that a person would get from an outage, before the outage. Each change below is a plausible edit.

        ### A second service on a taken port

        An agent adds Grafana to the database machine and gives it the port it knows, 5432.
      ''
      (docs.file "changes/second-service-on-5432.json")
      (docs.value (answerOf inputs dir "second-service-on-5432"))
      ''
        ### The database goes on the internet

        To reach it from outside, the agent changes `reach` to `internet`.
      ''
      (docs.file "changes/open-the-database.json")
      (docs.value (answerOf inputs dir "open-the-database"))
      ''
        ### The backup is switched off

        To save disk, the agent sets `backup` to `none` on the database machine.
      ''
      (docs.file "changes/stop-the-backup.json")
      (docs.value (answerOf inputs dir "stop-the-backup"))
      ''
        ### A production credential in the dev zone

        To test a deploy, the agent puts `prod-credentials` on the lab machine.
      ''
      (docs.file "changes/prod-token-to-lab.json")
      (docs.value (answerOf inputs dir "prod-token-to-lab"))
      ''
        ### A clone with the original's address
      ''
      (docs.file "changes/clone-with-same-addr.json")
      (docs.value (answerOf inputs dir "clone-with-same-addr"))
      ''
        ### A change that is fine

        The agent adds a wiki on the edge machine, on a free port. No rule breaks, so the change may land:
      ''
      (docs.file "changes/add-a-wiki.json")
      (docs.value (answerOf inputs dir "add-a-wiki"))
      (docs.caution "What Yen proves here" ''
        Yen proves rules about the fleet you describe: its machines, their fields, their services and their aspects. A service that opens a
        port without declaring it is not seen, and Yen does not read what a built system does when it runs. Declare what you care about,
        as the `port` and `reach` of a service above, and the rule holds across every machine and every change.
      '')
    ];

  checks =
    {
      inputs,
      dir,
      eq,
      ...
    }:
    let
      # a refused change: no error, and exactly the rule it breaks, at the scopes it names
      refused =
        c: rule: scopes:
        eq (answerOf inputs dir c) {
          ok = false;
          errors = [ ];
          violations = [
            (
              [
                "bad"
                rule
              ]
              ++ map (s: "fleet:main/${s}") scopes
            )
          ];
        };
    in
    {
      port = refused "second-service-on-5432" "unique-port" [
        "host:db1/service:grafana"
        "host:db1/service:postgres"
      ];
      public-database = refused "open-the-database" "database-not-public" [ "host:db1/service:postgres" ];
      backup = refused "stop-the-backup" "database-has-backup" [ "host:db1" ];
      credentials = refused "prod-token-to-lab" "no-prod-credentials-in-dev" [ "host:lab" ];
      address = refused "clone-with-same-addr" "unique-addr" [
        "host:db1"
        "host:lab2"
      ];
      fine = eq (answerOf inputs dir "add-a-wiki") {
        ok = true;
        errors = [ ];
        violations = [ ];
      };
    };
}
