# frozen_string_literal: true

module Entities
  class ClientEntity < Grape::Entity
    expose :id, documentation: { type: "Integer", desc: "Client ID" }
    expose :full_name, documentation: { type: "String", desc: "Client full name" }
    expose :email, documentation: { type: "String", desc: "Client email address" }
    expose :phone, documentation: { type: "String", desc: "Client phone number" }
    expose :client_type, documentation: { type: "String", desc: "Individual or Corporate" }
    expose :created_at, documentation: { type: "DateTime", desc: "Client creation date" }

    # Address information
    expose :address, documentation: { type: "Object", desc: "Client address information" } do |client|
      {
        street: client.street_address,
        city: client.city,
        state: client.state,
        postal_code: client.postal_code,
        country: client.country
      }
    end

    # Contact information
    expose :contact_info, documentation: { type: "Object", desc: "Additional contact information" } do |client|
      {
        primary_email: client.email,
        secondary_email: client.secondary_email,
        primary_phone: client.phone,
        secondary_phone: client.secondary_phone,
        preferred_contact_method: client.preferred_contact_method || "email"
      }
    end

    # Business information (for corporate clients)
    expose :business_info, if: ->(client, options) { client.client_type == "corporate" },
           documentation: { type: "Object", desc: "Business information for corporate clients" } do |client|
      {
        business_name: client.business_name,
        business_type: client.business_type,
        industry: client.industry,
        registration_number: client.registration_number,
        tax_id: client.tax_id
      }
    end
  end
end
