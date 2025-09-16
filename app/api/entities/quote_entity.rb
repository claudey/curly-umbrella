# frozen_string_literal: true

module Entities
  class QuoteEntity < Grape::Entity
    expose :id, documentation: { type: 'Integer', desc: 'Quote ID' }
    expose :quote_number, documentation: { type: 'String', desc: 'Unique quote reference number' }
    expose :status, documentation: { type: 'String', desc: 'Quote status' }
    expose :total_premium, documentation: { type: 'Float', desc: 'Total premium amount' }
    expose :coverage_amount, documentation: { type: 'Float', desc: 'Coverage amount' }
    expose :quote_date, documentation: { type: 'Date', desc: 'Quote generation date' }
    expose :valid_until, documentation: { type: 'Date', desc: 'Quote expiration date' }
    expose :created_at, documentation: { type: 'DateTime', desc: 'Creation timestamp' }
    
    # Insurance company information
    expose :insurance_company, documentation: { type: 'Object', desc: 'Insurance company details' } do |quote|
      {
        id: quote.insurance_company.id,
        name: quote.insurance_company.name,
        code: quote.insurance_company.code
      }
    end
    
    # Financial breakdown
    expose :financial_details, documentation: { type: 'Object', desc: 'Detailed financial breakdown' } do |quote|
      {
        base_premium: quote.base_premium,
        taxes: quote.taxes,
        fees: quote.fees,
        discounts: quote.discounts,
        total_premium: quote.total_premium,
        currency: 'USD' # TODO: Make configurable
      }
    end
    
    # Coverage details
    expose :coverage_details, documentation: { type: 'Object', desc: 'Coverage information' } do |quote|
      {
        coverage_type: quote.coverage_type,
        coverage_amount: quote.coverage_amount,
        deductible: quote.deductible,
        policy_term: quote.policy_term || '12 months'
      }
    end
    
    # Quote validity
    expose :validity_info, documentation: { type: 'Object', desc: 'Quote validity information' } do |quote|
      {
        valid_until: quote.valid_until,
        days_remaining: quote.valid_until ? (quote.valid_until - Date.current).to_i : nil,
        is_expired: quote.valid_until ? quote.valid_until < Date.current : false
      }
    end
  end
end