
// sdk_delete_post_request hook
//
// Wait for the resource to be deleted before setResourceUnmanaged.
if err != nil {
    return nil, err
}
r.ko.Status.SubscriptionStatus = aws.String(eventSubscriptionStatusDeleting)
return r, ackrequeue.NeededAfter(
    errors.New(fmt.Sprintf("resource is in %s state", *r.ko.Status.SubscriptionStatus)),
    10*time.Second)
