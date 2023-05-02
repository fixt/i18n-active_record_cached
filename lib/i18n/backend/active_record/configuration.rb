# frozen_string_literal: true

module I18n
  module Backend
    class ActiveRecord
      class Configuration
        attr_accessor :cleanup_with_destroy, :cache_translations, :cache_source, :logger, :simple_backend

        def initialize
          @cleanup_with_destroy = false
          @cache_translations = false
          @cache_source = :memory
          @logger = nil ## should respond to :info, :error
          @simple_backend = I18n::Backend::Simple.new

          I18n.exception_handler = lambda do |*args|
            return unless args.first.is_a?(MissingTranslation)
            locale = args.second
            key = args.third
            default = args.last[:default]

            if default.nil?
              @logger.error("Translation for (#{key}, #{locale}) not found in ActiveRecord or YML locales. No default provided")
              return "translation missing: #{locale} #{key}"
            end

            return default unless default.is_a? String

            @logger.error("Translation for (#{key}, #{locale}) not found in ActiveRecord or YML locales. Using default value: #{default}")

            ActiveRecord::Translation.create(locale: locale, key: key, value: default)

            return default
          end
        end
      end
    end
  end
end
