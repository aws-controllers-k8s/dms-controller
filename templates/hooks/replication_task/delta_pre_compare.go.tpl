
// delta_pre_compare hook
//
// Trigger an update if ReplicationTask should be started based on
// the latest state of the resource.
//
// a = desired
// b = latest
if shouldStartReplicationTask(b.ko) {
    delta.Add("Spec.StartReplicationTask", true, false)
}
