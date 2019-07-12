
census_entities = []

geozones_mapping_file = File.read(Rails.root.join("config", "geozones_mapping.json"))
place_slug_to_geozone_dict = Hash[
  JSON.parse(geozones_mapping_file).map do |geozone_name, places|
    places.map { |place| [place["name"].parameterize, geozone_name] }
  end.compact.flatten(1)
]

place_matcher = FuzzyMatch.new(place_slug_to_geozone_dict.keys)

geozones_dictionary = {}

CSV.foreach(Rails.root.join("config", "entidades_censo.csv"), headers: true, col_sep: "\;") do |row|
  next unless row[2].present? && row[4].present?

  census_entities.append({
    ine_code: row[0],
    nif: row[1],
    city_council: row[2],
    postal_code: row[3],
    entity: row[4],
    entity_code: row[5],
    city_council_name: row[6]
  })

  dict_slug, score1, _score2 = place_matcher.find_with_score(row[2].parameterize)

  if score1 && score1 > 0.75
    geozone_name = place_slug_to_geozone_dict[dict_slug]
    geozones_dictionary[row[4]] = geozone_name == "no_aplica" ? nil : geozone_name
  else
    puts "Unsure match for #{row[2].parameterize}. Closest is #{dict_slug} with score #{score1}"
  end
end

CENSUS_ENTITIES = census_entities.freeze
postal_codes = CENSUS_ENTITIES.map { |entity| entity[:postal_code] }.uniq

census_dictionary = {}

postal_codes.each do |code|
  census_dictionary[code] = CENSUS_ENTITIES.select { |entity| entity[:postal_code] == code }
                                           .map { |e| e[:entity_code] }.uniq
end

CENSUS_DICTIONARY = census_dictionary.freeze

GEOZONES_DICTIONARY = geozones_dictionary.freeze
ENTITIES_GEOZONES_DICTIONARY = JSON.parse(File.read(Rails.root.join("config", "entities_geozones_dict.json")))

puts JSON.pretty_generate(CENSUS_DICTIONARY) if Rails.env.development?
#puts JSON.pretty_generate(GEOZONES_DICTIONARY) if Rails.env.development?
puts JSON.pretty_generate(ENTITIES_GEOZONES_DICTIONARY) if Rails.env.development?

I18n.enforce_available_locales = false

module Consul
  class Application < Rails::Application
    require Rails.root.join("lib/custom/census_api")
    require Rails.root.join("lib/custom/census_caller")

    config.i18n.default_locale = :es
    config.i18n.available_locales = [:es]
  end
end

def skip_html(&block)
end
