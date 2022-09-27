# frozen_string_literal: true

module I18n
  module Backend
    class ActiveRecord
      class Configuration
        attr_accessor :cleanup_with_destroy, :cache_translations, :cache_source

        def initialize
          @cleanup_with_destroy = false
          @cache_translations = false
          @cache_source = :memory
        end
      end
    end
  end
end
