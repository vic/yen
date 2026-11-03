# A host serves an OpenAI-compatible endpoint and runs a swarm of agents. An agent is a kind of the host: a model, a
# prompt and a schedule. It owns the aspect that makes its systemd service and timer: on each run the agent asks
# `/v1/chat/completions` and keeps the answer in /var/lib/agents/<agent>. The endpoint is data: by default the
# host's own ollama, or any OpenAI-compatible server (vLLM, llama.cpp, a hosted API) with its key in a file.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.kinds.host = {
    fields = {
      endpoint = yen.lib.opt yen.lib.str "http://127.0.0.1:11434/v1"; # OpenAI-compatible base URL
      keyFile = yen.lib.maybe yen.lib.str; # a file with the API key, for an endpoint that needs one
    };
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
    kinds.agent = {
      fields = {
        model = yen.lib.str;
        prompt = yen.lib.str;
        every = yen.lib.opt yen.lib.str "hourly"; # a systemd calendar spec
      };
      aspects.service.nixos =
        { agent, host, ... }:
        {
          systemd.services."agent-${agent.name}" = {
            description = "agent ${agent.name}";
            serviceConfig = {
              Type = "oneshot";
              DynamicUser = true;
              StateDirectory = "agents/${agent.name}";
            }
            // lib.optionalAttrs (host.keyFile != null) { LoadCredential = "key:${host.keyFile}"; };
            path = [
              inputs.nixpkgs.legacyPackages.x86_64-linux.curl
              inputs.nixpkgs.legacyPackages.x86_64-linux.jq
            ];
            script = ''
              key=""
              if [ -n "''${CREDENTIALS_DIRECTORY:-}" ]; then key=$(cat "$CREDENTIALS_DIRECTORY/key"); fi
              jq -n --arg model ${lib.escapeShellArg agent.model} --arg prompt ${lib.escapeShellArg agent.prompt} \
                '{ model: $model, messages: [ { role: "user", content: $prompt } ] }' \
              | curl -sf ${lib.escapeShellArg "${host.endpoint}/chat/completions"} \
                  -H "Content-Type: application/json" -H "Authorization: Bearer $key" -d @- \
              | jq -r '.choices[0].message.content' > "$STATE_DIRECTORY/$(date +%s).md"
            '';
          };
          systemd.timers."agent-${agent.name}" = {
            wantedBy = [ "timers.target" ];
            timerConfig.OnCalendar = agent.every;
          };
        };
    };
  };
}
