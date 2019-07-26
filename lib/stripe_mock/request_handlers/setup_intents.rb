module StripeMock
  module RequestHandlers
    module SetupIntents
      def SetupIntents.included(klass)
        klass.add_handler 'post /v1/setup_intents',              :new_setup_intent
        klass.add_handler 'get /v1/setup_intents/(.*)',          :get_setup_intent
        klass.add_handler 'post /v1/setup_intents/(.*)/confirm', :confirm_setup_intent
        klass.add_handler 'post /v1/setup_intents/(.*)/cancel',  :cancel_setup_intent
        klass.add_handler 'post /v1/setup_intents/(.*)',         :update_setup_intent
      end

       # post /v1/setup_intents
      def new_setup_intent(route, method_url, params, headers)
        id = new_id('seti')

        setup_intents[id] = Data.mock_setup_intent(
          params.merge(
            id: id
          )
        )

        setup_intent = setup_intents[id].clone

        if params[:confirm]
          # When `confirm=true` is used, it is equivalent to creating and
          # confirming the SetupIntent in the same call.
          Stripe::SetupIntent.confirm(
            setup_intent[:id],
            setup_method: params[:setup_method]
          )
        else
          setup_intent
        end
      end

       # get /v1/setup_intents/:id
      def get_setup_intent(route, method_url, params, headers)
        id = method_url.match(route)[1] || params[:setup_intent]
        setup_intent = assert_existence :setup_intent, id, setup_intents[id]

        setup_intent.clone
      end

      # post /v1/setup_intents/:id/confirm
      def confirm_setup_intent(route, method_url, params, headers)
        allowed_params = [:payment_method, :payment_method_options, :return_url]

        id = method_url.match(route)[1]

        setup_intent = assert_existence :setup_intent, id, setup_intents[id]

        if !params[:payment_method] && !setup_intent[:payment_method]
          raise Stripe::InvalidRequestError.new(
            "You cannot confirm this SetupIntent because it's missing a payment method. Update the SetupIntent with a payment method and then confirm it again.",
            http_status: 400
          )
        end

        setup_intent = Util.rmerge(setup_intent, params.select { |k, _v| allowed_params.include?(k) })
        setup_intent[:status] = 'succeeded'

        setup_intents[id] = setup_intent
        setup_intent.clone
      end

      # post /v1/setup_intents/:id/cancel
      def cancel_setup_intent(route, method_url, params, headers)
        allowed_params = [:cancellation_reason]

        id = method_url.match(route)[1]

        setup_intent = assert_existence :setup_intent, id, setup_intents[id]
        setup_intent = Util.rmerge(setup_intent, params.select { |k, _v| allowed_params.include?(k) })
        setup_intent[:status] = 'canceled'

        setup_intents[id] = setup_intent
        setup_intent.clone
      end

      # post /v1/setup_intents/:id
      def update_setup_intent(route, method_url, params, headers)
        allowed_params =
          [:intent, :customer, :description, :metadata, :payment_method, :payment_method_types]

        id = method_url.match(route)[1]

        setup_intent = assert_existence :setup_intent, id, setup_intents[id]

        # When a customer is specified, the payment method must be specified too
        if params[:customer] && !params[:payment_method]
          raise Stripe::InvalidRequestError.new(
            "The customer #{params[:customer]} cannot be updated without also passing the payment method. Please include the payment method in the `payment_method` parameter on the SetupIntent.",
            http_status: 400
          )
        end

        # When a customer and a payment method is specified,
        # the payment method must be attached to a customer
        if params[:customer] && params[:payment_method]
          payment_method = assert_existence :payment_method, params[:payment_method], payment_methods[params[:payment_method]]
          if payment_method[:customer] != params[:customer]
            raise Stripe::InvalidRequestError.new(
              "The payment method supplied (#{payment_method[:id]}) does not belong to a Customer, but you supplied Customer #{params[:customer]}. Please attach the payment method to this Customer before using it with a SetupIntent.",
              http_status: 400
            )
          end
        end

        setup_intents[id] =
          Util.rmerge(setup_intent, params.select { |k, _v| allowed_params.include?(k)} )

        setup_intents[id].clone
      end
    end
  end
end
