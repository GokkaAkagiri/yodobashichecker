require 'active_record'

class PriceHistory < ActiveRecord::Base
  belongs_to :product
end
