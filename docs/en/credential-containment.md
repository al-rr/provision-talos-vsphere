# Credential Containment

Generated Talos machine configuration, `talosconfig`, kubeconfig, and related
client-access files are local runtime artifacts. They must never be committed,
copied into documentation, or treated as reusable templates.

## Containment Procedure

1. Stop staging or distributing the affected artifacts.
2. Remove affected artifacts from Git tracking only after owner approval; keep
   local files available until replacement access is confirmed.
3. Keep the repository ignore rules in place before regenerating artifacts.
4. Regenerate machine and client-access artifacts through the approved Talos
   lifecycle workflow, outside Terraform state and outside tracked paths.
5. Confirm Git no longer tracks the artifact names and that local working-tree
   status does not offer them for staging.

## Rotation Checklist

Treat any previously tracked credential-bearing artifact as exposed until the
owner completes an approved rotation. The owner must decide the maintenance
window and replacement sequence. Record only the completion status, never
credential values, in the issue or review evidence.

- Regenerate Talos cluster secrets and machine configuration where required.
- Replace Talos client access material and distribute it only through the
  approved local configuration path.
- Replace Kubernetes client access material and revoke obsolete access where
  supported by the cluster workflow.
- Verify new access before removing any final local fallback copy.
- Record the rotation completion and remaining recovery material without
  placing values in Git, logs, or issue comments.

## Target State and Ownership

The target state is user-scoped Talos configuration, managed by
`talos-toolchain` under the user's own configuration directory rather than
inside a repository checkout. Until that migration lands, `provision-talos-vsphere`
must not reintroduce credential-bearing generated artifacts into the checkout;
containment here is a stopgap, not the destination. The actual migration to
user-scoped configuration is a later, separately reviewed `talos-toolchain`
implementation and is out of scope for this repository.
