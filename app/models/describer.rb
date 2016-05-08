class Describer < ActiveRecord::Base
  has_many :movies,
    class_name: 'MovieDescriber'

  validate :name
end
