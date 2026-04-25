require "yaml"
require "set"

module Checklist
  Domain = Struct.new(:key, :items, keyword_init: true)
  Item   = Struct.new(:key, :domain, keyword_init: true)

  class Error < StandardError; end

  class << self
    def domains
      @domains ||= load_from_yaml
    end

    def items
      @items ||= domains.flat_map(&:items)
    end

    def item_keys
      @item_keys ||= items.map(&:key).to_set
    end

    def item(key)
      items_by_key[key]
    end

    def reset!
      @domains = @items = @item_keys = @items_by_key = nil
    end

    def yaml_path
      Rails.root.join("config", "checklist.yml")
    end

    private

    def items_by_key
      @items_by_key ||= items.index_by(&:key)
    end

    def load_from_yaml
      path = yaml_path
      raise Error, "checklist.yml not found at #{path}" unless path.file?

      raw = YAML.safe_load_file(path, permitted_classes: [])
      raise Error, "checklist.yml must be a hash" unless raw.is_a?(Hash)

      raw.map do |domain_key, payload|
        unless payload.is_a?(Hash) && payload["items"].is_a?(Array)
          raise Error, "domain '#{domain_key}' is missing items array"
        end

        items = payload["items"].map do |item_key|
          Item.new(key: item_key, domain: domain_key)
        end
        Domain.new(key: domain_key, items: items)
      end
    end
  end
end
