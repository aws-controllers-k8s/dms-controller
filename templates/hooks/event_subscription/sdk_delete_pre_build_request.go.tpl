
// sdk_delete_pre_build_request hook
//
// Do not attempt to delete the resource if it is already in the
// process of being deleted.
if r.ko.Status.SubscriptionStatus != nil && *r.ko.Status.SubscriptionStatus == eventSubscriptionStatusDeleting {
    return r, ackrequeue.NeededAfter(
        errors.New(fmt.Sprintf("resource is in %s state", *r.ko.Status.SubscriptionStatus)),
        10*time.Second)
}
