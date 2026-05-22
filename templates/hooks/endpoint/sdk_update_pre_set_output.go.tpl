
// sdk_update_pre_set_output hook
//
// Sync the latest tags.
if delta.DifferentAt("Spec.Tags") {
    if err = rm.syncTags(ctx, desired, latest); err != nil {
        return nil, err
    }
}
