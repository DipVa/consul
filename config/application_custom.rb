module Consul
  class Application < Rails::Application
    require Rails.root.join("lib/custom/census_api")
    require Rails.root.join("lib/custom/census_caller")

    config.i18n.default_locale = :es
    config.i18n.available_locales = [:es, :en]
  end
end

def skip_html(&block)
end
