module AlchemyConcern
  extend ActiveSupport::Concern

  included do
    validate :validate_alchemy_options
  end

  def validate_alchemy_options
    unless alchemy_api_key.present?
      errors.add(:base, 'alchemy_api_key is required to authenticate with the Alchemy API.  You can provide these as options to this Agent or as Credentials with the same name.')
    end
  end

  def alchemy_api_key
    options['alchemy_api_key'].presence || credential('alchemy_api_key')
  end

  def configure_alchemy
    AlchemyAPI.configure do |config|
      config.apikey = alchemy_api_key
    end
  end
end
