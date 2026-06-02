{
  description = "Container Days 2026 - Calico v3.32.0 Demo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      calicoctl = pkgs.fetchurl {
        url = "https://github.com/projectcalico/calico/releases/download/v3.32.0/calicoctl-linux-amd64";
        hash = "sha256-TJzjC/rXijezatSmdUWgJYk48PvLVGXMWrq+SIYcrUE=";
      };

      calicoctl-package = pkgs.runCommand "calicoctl" { } ''
        mkdir -p $out/bin
        cp ${calicoctl} $out/bin/calicoctl
        ln -s $out/bin/calicoctl $out/bin/kubectl-calico
        chmod +x $out/bin/calicoctl
      '';

    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        shellHook = ''
          export EDITOR=${pkgs.nano}/bin/nano
          export KUBECONFIG=$PWD/kubeconfig
        '';

        packages = with pkgs; [
          calicoctl-package
          kubectl
          k9s
          kind
          kubernetes-helm
          nano
          pv
        ] ++ [
          # ── Demo lifecycle ──────────────────────────────────────
          (pkgs.writeShellApplication {
            name = "demo-setup";
            runtimeInputs = with pkgs; [ kubectl kind docker netcat pv ];
            text = ''
              echo "► Full setup — dummy interface, kind cluster, Calico, Postgres, then start exfiltration sink"
              echo "  $ ./setup.sh"
              echo ""
              exec ${./setup.sh}
            '';
          })

          (pkgs.writeShellApplication {
            name = "demo-cleanup";
            runtimeInputs = with pkgs; [ kubectl kind ];
            text = ''
              echo "► Teardown — delete cluster, remove dummy interface, kill netcat"
              echo "  $ ./cleanup.sh"
              echo ""
              exec ${./cleanup.sh}
            '';
          })

          # ── Whisker UI ───────────────────────────────────────────
          (pkgs.writeShellApplication {
            name = "demo-whisker";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Port-forward to Whisker observability UI"
              echo "  $ kubectl port-forward -n calico-system svc/whisker 8080:8081"
              echo ""
              echo "Then open: http://localhost:8080"
              echo ""
              exec kubectl port-forward -n calico-system svc/whisker 8080:8081
            '';
          })

          # ── Part 1: Traditional troubleshooting ──────────────────
          (pkgs.writeShellApplication {
            name = "demo-troubleshoot";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Traditional troubleshooting — pods, logs, service"
              echo "  $ kubectl get pods -A"
              echo "  $ kubectl logs -n postgres release-name-postgres-0"
              echo "  $ kubectl get svc -n postgres"
              echo ""

              echo "--- Pods ---"
              kubectl get pods -A
              echo ""
              echo "--- Postgres logs ---"
              kubectl logs -n postgres release-name-postgres-0
              echo ""
              echo "--- Postgres service ---"
              kubectl get svc -n postgres
            '';
          })
          # ── Part 3: Staged policy ────────────────────────────────
          (pkgs.writeShellApplication {
            name = "demo-apply-staged";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Apply staged (dry-run) policy — denies egress but does NOT enforce"
              echo "  $ kubectl apply -f staged-cnp.yaml"
              echo ""
              kubectl apply -f staged-cnp.yaml
              echo ""
              echo "Switch to Whisker → Action filter → Staged Action: Deny"
            '';
          })

          (pkgs.writeShellApplication {
            name = "demo-delete-staged";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Remove staged policy"
              echo "  $ kubectl delete -f staged-cnp.yaml"
              echo ""
              kubectl delete -f staged-cnp.yaml
            '';
          })

          # ── Part 4: NetworkPolicy vs ClusterNetworkPolicy ───────
          (pkgs.writeShellApplication {
            name = "demo-apply-np";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Apply namespace-scoped NetworkPolicy — developers can delete this"
              echo "  $ kubectl apply -f networkpolicy.yaml"
              echo ""
              kubectl apply -f networkpolicy.yaml
              echo ""
              echo "Exfiltration should now be DENIED in Whisker."
            '';
          })

          (pkgs.writeShellApplication {
            name = "demo-delete-np";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Delete NetworkPolicy — simulating a developer removing it"
              echo "  $ kubectl delete -f networkpolicy.yaml"
              echo ""
              kubectl delete -f networkpolicy.yaml
              echo ""
              echo "Exfiltration should RESUME in Whisker — the policy was just a recommendation."
            '';
          })

          (pkgs.writeShellApplication {
            name = "demo-apply-cnp";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Apply ClusterNetworkPolicy in Admin tier — developers CANNOT override this"
              echo "  $ kubectl apply -f cluster-networkpolicy.yaml"
              echo ""
              kubectl apply -f cluster-networkpolicy.yaml
              echo ""
              echo "Exfiltration is DENIED permanently. Only cluster admins can modify this."
            '';
          })
          (pkgs.writeShellApplication {
            name = "demo-apply-allow-np";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Apply permissive allow-all NetworkPolicy — developers can create this"
              echo "  $ kubectl apply -f networkpolicy-allow.yaml"
              echo ""
              kubectl apply -f networkpolicy-allow.yaml
              echo ""
              echo "Exfiltration should STILL be DENIED — the Admin tier deny takes precedence."
            '';
          })

          (pkgs.writeShellApplication {
            name = "demo-delete-allow-np";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Delete permissive NetworkPolicy (cleanup)"
              echo "  $ kubectl delete -f networkpolicy-allow.yaml"
              echo ""
              kubectl delete -f networkpolicy-allow.yaml
            '';
          })

          (pkgs.writeShellApplication {
            name = "demo-delete-cnp";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Delete ClusterNetworkPolicy (cleanup only)"
              echo "  $ kubectl delete -f cluster-networkpolicy.yaml"
              echo ""
              kubectl delete -f cluster-networkpolicy.yaml
            '';
          })

          # ── Verification ──────────────────────────────────────────
          (pkgs.writeShellApplication {
            name = "demo-verify";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Verify demo environment — Calico, Postgres, exfiltration"
              echo "  $ kubectl get pods -n calico-system"
              echo "  $ kubectl get pods -n postgres"
              echo "  $ kubectl exec ... ps aux | grep nc"
              echo ""

              echo "--- Calico pods ---"
              kubectl get pods -n calico-system
              echo ""
              echo "--- Postgres pod ---"
              kubectl get pods -n postgres
              echo ""
              echo "--- Exfiltration process ---"
              kubectl exec -n postgres release-name-postgres-0 -- ps aux 2>&1 | grep -E "nc|stat_collector" | grep -v grep
            '';
          })
          (pkgs.writeShellApplication {
            name = "demo-check-tiers";
            runtimeInputs = with pkgs; [ kubectl ];
            text = ''
              echo "► Show Calico policy tiers"
              echo "  $ kubectl get tiers.crd.projectcalico.org"
              echo ""
              kubectl get tiers.crd.projectcalico.org
            '';
          })
        ];
      };
    };
}
