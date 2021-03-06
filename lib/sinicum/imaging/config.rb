module Sinicum
  module Imaging
    # Represents the configuraiton of the imaging module and its renderers
    class Config
      IMAGING_CONFIG_FILE = "config/imaging.yml"

      require 'fileutils'

      include Sinicum::Logger

      # The version number of the imaging directory format. Stored in the file `VERSION`.
      VERSION = "1.0"

      # Default Root directory
      DEFAULT_ROOT_DIR = File.join("tmp", "imaging")

      # If the directory sturcture is already set up
      @@dir_setup = false

      # The root directory under which all files are stored
      attr_reader :root_dir, :renderer, :apps, :srcset_options

      # The directory to store all rendered files in
      #
      # @return [String]
      def file_dir
        File.join(@root_dir, "files")
      end

      # The directory to store temporary files in
      #
      # @return [String]
      def tmp_dir
        File.join(@root_dir, "tmp")
      end

      # Path of the file that stores the version of the directory format.
      #
      # @return [String]
      def version_file
        File.join(@root_dir, "VERSION")
      end

      # Initialize and setup the configuration
      #
      # @param [String, nil] configfile Path of the configuration file. If `nil`,
      # `Rails.root/config/imaging.yml` will be used.
      def self.configure(configfile)
        config = Config.send(:new, configfile)
        @@__instance__ = config
        @@config = true
        config
      end

      # Obtain an instance of the imaging configuration.
      def self.instance
        @@__instance__ ||= false
        fail "Class is not yet configured" unless @@__instance__
        @@__instance__
      end

      # Returns the converter class for a given renderer
      #
      # @param [Symbol] the renderer to use
      # @return [Sinicum::Imaging::Converter] the converter to use for this renderer
      def converter(renderer)
        result = nil
        renderer_config = @renderer[renderer.to_s]
        result = render_type(renderer_config) if renderer_config
        result ||= DefaultConverter.new(nil)
        result
      end

      def self.read_configuration
        config_file = File.join(Rails.root, IMAGING_CONFIG_FILE)
        if Rails.env.production?
          @@conf ||= configure(config_file)
        else
          configure(config_file)
        end
      end

      private
      attr_reader :config_file

      def initialize(configfile)
        @config_file = configfile
        read_config
      end

      def render_type(renderer_config)
        case
        when renderer_config["render_type"] == "default"
          Sinicum::Imaging::DefaultConverter.new(renderer_config)
        when renderer_config["render_type"] == "resize_crop"
          Sinicum::Imaging::ResizeCropConverter.new(renderer_config)
        when renderer_config["render_type"] == "resize_max"
          Sinicum::Imaging::MaxSizeConverter.new(renderer_config)
        when renderer_config["render_class_name"]
          renderer_config["render_class_name"].classify.constantize.new(renderer_config)
        else
          nil
        end
      end

      def read_config
        config = YAML.load_file(config_file)
        check_configuration(config)
        @root_dir = config['root_dir'] || File.join(Rails.root, DEFAULT_ROOT_DIR)
        setup_directory_structure(@root_dir)
        @renderer = config['renderer']
        @apps = config['apps']
        @srcset_options = config['srcset_options']
      end

      def check_configuration(config)
        renderers = config['renderer']
        apps = config['apps']
        srcset_options = config['srcset_options']
        if renderers[Imaging::DEFAULT_CONVERTER_NAME]
          fail "No renderer with name '#{Imaging::DEFAULT_CONVERTER_NAME}' is allowed"
        end
        if apps.blank?
          fail "No apps are configured. Please check the README for an example."
        end
        if srcset_options.kind_of?(Array)
          srcset_options.each do |option|
            unless option.kind_of?(Array) && option[0].is_a?(String) && option[0].match(/[0-9]{3}/) &&
              option[1].is_a?(String) && option[1].match(/([0-4]\.[1-9]{1,2}x)|([2-4]x)/)
              fail "Srcset options are not defined correctly."
            end
          end
        else
          unless srcset_options.nil?
            fail "No Srcset options defined."
          end
        end
      end

      def setup_directory_structure(dir)
        unless @@dir_setup
          @@dir_setup = true
          FileUtils.mkdir_p(root_dir) unless File.exist?(root_dir)
          unless File.exist?(version_file)
            File.open(version_file, "w") { |f| f.write(VERSION + "\n") }
          end
          FileUtils.mkdir_p(dir) unless File.exist?(dir)
          FileUtils.mkdir_p(tmp_dir) unless File.exist?(tmp_dir)
          FileUtils.mkdir_p(file_dir) unless File.exist?(file_dir)
        end
      end

      def self.new(*args)
        super
      end

      def self.allocate
        super
      end
    end
  end
end
