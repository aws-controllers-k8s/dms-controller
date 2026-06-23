
// sdk_update_pre_build_request hook
//
// Sync the latest tags.
if delta.DifferentAt("Spec.Tags") {
    if err = rm.syncTags(ctx, desired, latest); err != nil {
        return nil, err
    }
}
if !delta.DifferentExcept("Spec.Tags") {
    return desired, nil
}

// sdk_update_pre_build_request hook
//
// Make sure the event subscription is in a steady state before updating
// it.
if !hasSteadyState(latest.ko) {
    ackcondition.SetSynced(latest, corev1.ConditionFalse,
        aws.String(fmt.Sprintf("EventSubscription is in %v state", *latest.ko.Status.SubscriptionStatus)), nil)
    return latest, nil
}
