# Service for managing the users.
angular.module 'mnoEnterpriseAngular'
  .service 'MnoeProvisioning', ($q, $log, MnoeApiSvc, MnoeOrganizations, MnoErrorsHandler) ->
    _self = @

    subscriptionsApi = (id) -> MnoeApiSvc.one('/organizations', id).all('subscriptions')

    subscription = {}
    selectedCurrency = ""

    @subscriptionsPromise = null

    defaultSubscription = {
      id: null
      product: null
      product_pricing: null
      custom_data: {}
    }

    @getSubscriptionsPromise = ->
      _self.subscriptionsPromise

    @setSubscription = (s) ->
      subscription = s

    @getCachedSubscription = () ->
      subscription

    @setSelectedCurrency = (c) ->
      selectedCurrency = c

    @getSelectedCurrency = () ->
      selectedCurrency

    # Return the subscription
    # if productNid: return the default subscription
    # if subscriptionId: return the fetched subscription
    # else: return the subscription in cache (edition mode)
    @initSubscription = ({productId = null, subscriptionId = null, cart = null}) ->
      deferred = $q.defer()
      # Edit a subscription
      if !_.isEmpty(subscription)
        deferred.resolve(subscription)
      else if subscriptionId?
        _self.fetchSubscription(subscriptionId, cart).then(
          (response) ->
            angular.copy(response, subscription)
            deferred.resolve(subscription)
        )
      else if productId?
        # Create a new subscription to a product
        angular.copy(defaultSubscription, subscription)
        deferred.resolve(subscription)
      else
        deferred.resolve({})

      return deferred.promise

    @createSubscription = (s, c) ->
      deferred = $q.defer()
      subscription_params = {currency: c, product_id: s.product.id, product_pricing_id: s.product_pricing?.id, max_licenses: s.max_licenses, custom_data: s.custom_data, cart_entry: s.cart_entry}
      MnoeOrganizations.get().then(
        (response) ->
          subscriptionsApi(response.organization.id).post({subscription: subscription_params}).then(
            (response) ->
              deferred.resolve(response)
          )
      )
      return deferred.promise

    @updateSubscription = (s, c) ->
      deferred = $q.defer()
      MnoeOrganizations.get().then(
        (response) ->
          subscription.patch({subscription: {currency: c, product_id: s.product.id, product_pricing_id: s.product_pricing?.id,
          max_licenses: s.max_licenses, custom_data: s.custom_data, edit_action: s.edit_action, cart_entry: s.cart_entry}}).then(
            (response) ->
              deferred.resolve(response)
          )
      )
      return deferred.promise

    # Detect if the subscription should be a POST or A PUT and call corresponding method
    @saveSubscription = (subscription, currency) ->
      unless subscription.id
        _self.createSubscription(subscription, currency)
      else
        _self.updateSubscription(subscription, currency)

    @fetchSubscription = (id, cart) ->
      deferred = $q.defer()
      MnoeOrganizations.get().then(
        (response) ->
          params = if cart then { 'subscription[cart_entry]': 'true' } else {}
          MnoeApiSvc.one('/organizations', response.organization.id).one('subscriptions', id).get(params).then(
            (response) ->
              deferred.resolve(response)
          )
      )
      return deferred.promise

    @getSubscriptions = (params = {}, cart = false) ->
      return _self.subscriptionsPromise if cart && _self.subscriptionsPromise?

      deferred = $q.defer()
      MnoeOrganizations.get().then(
        (response) ->
          subscriptionsApi(response.organization.id).getList(params).then(
            (response) ->
              deferred.resolve(response)
          )
      )
      _self.subscriptionsPromise = deferred.promise if cart
      return deferred.promise

    @getProductSubscriptions = (productId) ->
      deferred = $q.defer()
      MnoeOrganizations.get().then(
        (response) ->
          params = { where: { product_id: productId } }
          subscriptionsApi(response.organization.id).getList(params).then(
            (response) ->
              deferred.resolve(response)
          )
      )
      return deferred.promise

    @cancelSubscription = (s) ->
      MnoeOrganizations.get().then(
        (response) ->
          subscription_params = { cart_entry: s.cart_entry }
          MnoeApiSvc.one('organizations', response.organization.id).one('subscriptions', s.id).post('/cancel', {subscription: subscription_params}).catch(
            (error) ->
              MnoErrorsHandler.processServerError(error)
              $q.reject(error)
          )
      )

    @getSubscriptionEvents = (subscriptionId) ->
      deferred = $q.defer()
      MnoeOrganizations.get().then(
        (response) ->
          MnoeApiSvc.one('organizations', response.organization.id).one('subscriptions', subscriptionId).customGETLIST('subscription_events').then(
            (response) ->
              deferred.resolve(response)
          )
      )
      return deferred.promise

    @deleteCartSubscriptions = ->
      deferred = $q.defer()
      MnoeOrganizations.get().then(
        (response) ->
          MnoeApiSvc.one('organizations', response.organization.id).one('subscriptions').post('/cancel_cart_subscriptions').then(
            (response) ->
              deferred.resolve(response)
          )
      )
      return deferred.promise

    @submitCartSubscriptions = ->
      deferred = $q.defer()
      MnoeOrganizations.get().then(
        (response) ->
          MnoeApiSvc.one('organizations', response.organization.id).one('subscriptions').post('/submit_cart_subscriptions').then(
            (response) ->
              deferred.resolve(response)
          )
      )
      return deferred.promise

    @emptySubscriptions = () ->
      _self.subscriptionsPromise = null

    @refreshSubscriptions = ->
      _self.emptySubscriptions()
      _self.getSubscriptions({ where: {staged_subscriptions: true } })

    return
