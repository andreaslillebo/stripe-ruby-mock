require 'spec_helper'

shared_examples 'SetupIntent API' do
  let(:billing_details) do
    {
      address: {
        city: 'North New Portland',
        country: 'US',
        line1: '2631 Bloomfield Way',
        line2: 'Apartment 5B',
        postal_code: '05555',
        state: 'ME'
      },
      email: 'john@example.com',
      name: 'John Doe',
      phone: '555-555-5555'
    }
  end
  let(:card_details) do
    {
      number: 4242_4242_4242_4242,
      exp_month: 9,
      exp_year: (Time.now.year + 5),
      cvc: 999
    }
  end
  let(:payment_method) do
    Stripe::PaymentMethod.create(
      type: type,
      billing_details: billing_details,
      card: card_details,
      metadata: {
        order_id: '123456789'
      }
    )
  end
  let(:type) { 'card' }

  # post /v1/setup_intents
  describe 'Create a SetupIntent', live: true do
    let(:setup_intent) { Stripe::SetupIntent.create }

    it 'creates a setup intent with a valid id', live: false do
      expect(setup_intent.id).to match(/^test_seti/)
    end
  end

  # get /v1/setup_intents/:id
  describe 'Retrieve a SetupIntent', live: true do
    it 'retrieves a given setup intent' do
      original = Stripe::SetupIntent.create
      setup_intent = Stripe::SetupIntent.retrieve(original.id)

      expect(setup_intent.id).to eq(original.id)
    end
  end

  # post /v1/setup_intents/:id/confirm
  describe 'Confirm a SetupIntent', live: true do
    let(:setup_intent) { Stripe::SetupIntent.create }

    it 'changes the status to `succeeded`' do
      expect { Stripe::SetupIntent.confirm(setup_intent.id, payment_method: payment_method.id) }
        .to change { Stripe::SetupIntent.retrieve(setup_intent.id).status }
        .from('requires_payment_method').to('succeeded')
    end

    context 'when no payment method is given' do
      it 'raises invalid requestion exception' do
        expect { Stripe::SetupIntent.confirm(setup_intent.id) }
          .to raise_error(Stripe::InvalidRequestError)
      end
    end
  end

  # post /v1/setup_intents/:id/cancel
  describe 'Cancel a SetupIntent', live: true do
    let(:setup_intent) { Stripe::SetupIntent.create }

    it 'changes the status to `cancelled`' do
      expect { Stripe::SetupIntent.cancel(setup_intent.id) }
        .to change { Stripe::SetupIntent.retrieve(setup_intent.id).status }
        .from('requires_payment_method').to('canceled')
    end
  end

  # post /v1/setup_intents/:id
  describe 'Update a SetupIntent', live: true do
    let(:customer) { Stripe::Customer.create }
    let(:customer_with_payment_method) do
      Stripe::PaymentMethod.attach(payment_method.id, customer: customer)
      customer
    end
    let(:setup_intent) { Stripe::SetupIntent.create }

    context 'for a customer with an attached payment method' do
      it 'updates the customer' do
        expect do
          Stripe::SetupIntent.update(
            setup_intent.id,
            customer: customer_with_payment_method.id,
            payment_method: payment_method.id
          )
        end.to change { Stripe::SetupIntent.retrieve(setup_intent.id).customer }
          .from(nil).to(customer_with_payment_method.id)
      end
    end

    context 'for a customer without a payment method' do
      it 'raises invalid requestion exception' do
        expect do
          Stripe::SetupIntent.update(
            setup_intent.id,
            customer: customer.id,
            payment_method: payment_method.id
          )
        end.to raise_error(Stripe::InvalidRequestError)
      end
    end

    context 'when only updating the customer' do
      it 'raises invalid requestion exception' do
        expect { Stripe::SetupIntent.update(setup_intent.id, customer: customer.id) }
          .to raise_error(Stripe::InvalidRequestError)
      end
    end

    context 'when only updating the payment method' do
      it 'updates the payment method' do
        expect do
          Stripe::SetupIntent.update(setup_intent.id, payment_method: payment_method.id)
        end.to change { Stripe::SetupIntent.retrieve(setup_intent.id).payment_method }
          .from(nil).to(payment_method.id)
      end
    end
  end
end
