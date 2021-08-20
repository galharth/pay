module Pay
  # Adds Pay methods to ActiveRecord models

  module Attributes
    extend ActiveSupport::Concern

    module CustomerExtension
      extend ActiveSupport::Concern

      included do
        has_many :pay_customers, class_name: "Pay::Customer", as: :owner, inverse_of: :owner, dependent: :destroy
        has_many :charges, through: :pay_customers, class_name: "Pay::Charge", dependent: :destroy
        has_many :subscriptions, through: :pay_customers, class_name: "Pay::Subscription", dependent: :destroy
        has_one :payment_processor, -> { where(default: true) }, class_name: "Pay::Customer", as: :owner, inverse_of: :owner

        after_commit :cancel_active_subscriptions!, on: :destroy
      end

      # Changes a user's payment processor
      #
      # This has several effects:
      # - Finds or creates a Pay::Customer for the process and marks it as default
      # - Removes the default flag from all other Pay::Customers
      # - Removes the default flag from all Pay::PaymentMethods
      def set_payment_processor(processor_name, allow_fake: false, **attributes)
        raise Pay::Error, "Processor `#{processor_name}` is not allowed" if processor_name.to_s == "fake_processor" && !allow_fake

        ActiveRecord::Base.transaction do
          pay_customers.update_all(default: false)
          pay_customer = pay_customers.where(processor: processor_name).first_or_initialize
          pay_customer.update!(attributes.merge(default: true))
        end

        # Return new payment processor
        reload_payment_processor
      end
    end

    class_methods do
      def pay_customer
        include Billable::SyncCustomer
        include CustomerExtension
      end

      def pay_merchant
        has_many :pay_merchants, class_name: "Pay::Merchant", as: :owner, inverse_of: :owner
        has_one :merchant, -> { where(default: true) }, class_name: "Pay::Merchant", as: :owner, inverse_of: :owner

        define_method :set_merchant_processor do |processor_name|
          ActiveRecord::Base.transaction do
            pay_merchants.update_all(default: false)

            pay_merchant = pay_merchants.where(processor: processor_name).first_or_initialize
            pay_merchant.update!(processor: processor_name, default: true)
          end
        end
      end
    end

    private

    def cancel_active_subscriptions!
      byebug
    end

  end
end
