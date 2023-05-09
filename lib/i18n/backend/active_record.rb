# frozen_string_literal: true

require 'i18n/backend/base'
require 'i18n/backend/active_record/translation'

module I18n
  module Backend
    class ActiveRecord
      autoload :Missing,       'i18n/backend/active_record/missing'
      autoload :StoreProcs,    'i18n/backend/active_record/store_procs'
      autoload :Translation,   'i18n/backend/active_record/translation'
      autoload :Configuration, 'i18n/backend/active_record/configuration'

      class << self
        def configure
          yield(config) if block_given?
        end

        def config
          @config ||= Configuration.new
        end

        def reload_key!(key, value)
          log("Reloading #{key} in cache. Setting to #{value}")
          return reload! if config.cache_source == :memory

          config.cache_source.write(key, value)
        end
      end

      def initialize
        reload!
      end

      module Implementation
        include Base
        include Flatten

        def available_locales
          Translation.available_locales
        rescue ::ActiveRecord::StatementInvalid
          []
        end



        def store_translations(locale, data, options = {})
          escape = options.fetch(:escape, true)
          cache_values = {}
          flatten_translations(locale, data, escape, false).each do |key, value|
            translation = Translation.locale(locale).lookup(expand_keys(key))

            if self.class.config.cleanup_with_destroy
              translation.destroy_all
            else
              translation.delete_all
            end

            translation = Translation.find_or_create_by(locale: locale.to_s, key: key.to_s, value: value)

            cache_values[translation.cache_key] = value if translation.using_redis_cache?
          end

          if self.class.config.cache_translations
            (reload! && return) if self.class.config.cache_source == :memory

            cache_values.each { |key, value| reload_key!(key, value) }
          end
        end

        def reload_key!(key, value)
          log("Reloading #{key} in cache. Setting to #{value}")
          return reload! if self.class.config.cache_source == :memory

          self.class.config.cache_source.write(key, value)
        end

        def reload!
          log('Reloading translations')
          @translations = nil
          return self unless self.class.config.cache_source
          return self if self.class.config.cache_source == :memory

          self.class.config.cache_source.delete_matched('i18n*')
          log('Cleared cache')
          self
        end

        def initialized?
          !@translations.nil?
        end

        def init_translations
          @translations = Translation.to_h
        end

        def translations(do_init: false)
          init_translations if do_init || !initialized?
          @translations ||= {}
        end

        protected

        def lookup(locale, key, scope = [], options = {})
          key = normalize_flat_keys(locale, key, scope, options[:separator])
          key = key[1..-1] if key.first == '.'
          key = key[0..-2] if key.last == '.'

          if self.class.config.cache_translations
            keys = ([locale] + key.split(I18n::Backend::Flatten::FLATTEN_SEPARATOR)).map(&:to_sym)

            return translations.dig(*keys) if self.class.config.cache_source == :memory
          end

          result = if self.class.config.cache_translations
            cache_key = "i18n.#{locale}.#{key}"
            self.class.config.cache_source.fetch(cache_key) do
              log("Translation for (#{key}, #{locale}) not found in Cache")
              find_translation(locale, key)
            end
          else
            find_translation(locale, key)
          end

          return result unless result.nil?

          create_record_from_simple_backend_if_possible_otherwise_nil(locale, key)
        end

        def find_translation(locale, key)
          result = if key == ''
            Translation.locale(locale).all
          else
            Translation.locale(locale).lookup(key)
          end

          if result.empty?
            nil
          elsif result.first.key == key
            result.first.value
          else
            result = result.inject({}) do |hash, translation|
              hash.deep_merge build_translation_hash_by_key(key, translation)
            end
            result.deep_symbolize_keys
          end
        end

        def build_translation_hash_by_key(lookup_key, translation)
          hash = {}

          chop_range = if lookup_key == ''
            0..-1
          else
            (lookup_key.size + FLATTEN_SEPARATOR.size)..-1
          end
          translation_nested_keys = translation.key.slice(chop_range).split(FLATTEN_SEPARATOR)
          translation_nested_keys.each.with_index.inject(hash) do |iterator, (key, index)|
            iterator[key] = translation_nested_keys[index + 1] ?  {} : translation.value
            iterator[key]
          end

          hash
        end

        # For a key :'foo.bar.baz' return ['foo', 'foo.bar', 'foo.bar.baz']
        def expand_keys(key)
          key.to_s.split(FLATTEN_SEPARATOR).inject([]) do |keys, k|
            keys << [keys.last, k].compact.join(FLATTEN_SEPARATOR)
          end
        end

        def create_record_from_simple_backend_if_possible_otherwise_nil(locale, key)
          simpleValue = I18n::Backend::Simple.new.translate(locale, key, { raise: false, throw: false })

          ActiveRecord::Translation.create(locale: locale.to_s, key: key, value: simpleValue)

          simpleValue
        end

        def log(message, type = :info)
          return if self.class.config.logger.nil?

          self.class.config.logger.send(type, message)
        end
      end

      include Implementation
    end
  end
end
