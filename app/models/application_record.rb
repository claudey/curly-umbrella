class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Set up acts_as_tenant for multi-tenancy
  include ActsAsTenant::ModelExtensions
end
