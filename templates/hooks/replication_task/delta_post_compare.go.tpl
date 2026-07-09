
// delta_post_compare hook
//
// Trigger an update if ReplicationTask should be stopped based on
// the latest state of the resource.
//
// a = desired
// b = latest
if shouldStopReplicationTask(b.ko, delta) {
    delta.Add("Spec.StartReplicationTask", false, true)
}
