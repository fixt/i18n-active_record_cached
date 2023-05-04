# frozen_string_literal: true

module I18n
  module Backend
    class ActiveRecord
      class Configuration
        attr_accessor :cleanup_with_destroy, :cache_translations, :cache_source, :logger, :simple_backend,
                      :exception_handler

        def initialize
          @cleanup_with_destroy = false
          @cache_translations = false
          @cache_source = :memory
          @logger = nil ## should respond to :info, :error
          @simple_backend = I18n::Backend::Simple.new
          @exception_handler = nil

          I18n.exception_handler = @exception_handler unless @exception_handler.nil?
        end
      end
    end
  end
end
