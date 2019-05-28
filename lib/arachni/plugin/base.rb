=begin
    Copyright 2010-2017 Sarosys LLC <http://www.sarosys.com>

    This file is part of the Arachni Framework project and is subject to
    redistribution and commercial restrictions. Please see the Arachni Framework
    web site for more information on licensing and terms of use.
=end

require_relative "formatter"

module Arachni
  module Plugin

    # An abstract class which all plugins must extend.
    # 每个插件需要继承的基类
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@arachni-scanner.com>
    # @abstract
    class Base < Component::Base
      include Component
      include MonitorMixin

      # @return   [Hash]
      #   Plugin options.
      attr_reader :options

      # @return   [Framework]
      attr_reader :framework

      # @param    [Framework]   framework
      # @param    [Hash]        options
      #   Options to pass to the plugin.
      # 传递给插件的选项。
      def initialize(framework, options)
        @framework = framework
        @options = options
      end

      # @note **OPTIONAL**
      #
      # Gets called right after the plugin is initialized and is used to prepare
      # its data or setup hooks.
      # 在初始化插件后立即调用，并用于准备其数据或设置挂钩。
      #
      # This method should not block as the system will wait for it to return prior
      # to progressing.
      # 此方法不应阻止，因为系统将在进行之前等待它返回。
      #
      # @abstract
      def prepare
      end

      # @note **OPTIONAL**
      #
      # Gets called instead of {#prepare} when restoring a suspended plugin.
      # If no {#restore} method has been defined, {#prepare} will be called instead.
      # 在恢复挂起的插件时，会调用而不是{#prepare}。如果没有定义{#restore}方法，则会调用{#prepare}。
      #
      # @param   [Object] state    State to restore.
      #
      # @see #suspend
      # @abstract
      def restore(state = nil)
      end

      # @note **REQUIRED**
      #
      # Gets called right after {#prepare} and delivers the plugin payload.
      # 在{#prepare}之后立即调用并传递插件有效负载。
      #
      # This method will be ran in its own thread, in parallel to any other system
      # operation. However, once its job is done, the system will wait for this
      # method to return prior to exiting.
      # 此方法将在其自己的线程中运行，与任何其他系统操作并行运行。 但是，一旦完成其工作，系统将等待此方法在退出之前返回。
      #
      # @abstract
      def run
      end

      # @note **OPTIONAL**
      #
      # Gets called right after {#run} and is used for generic clean-up.
      # 在{#run}之后立即调用并用于通用清理。
      #
      # @abstract
      def clean_up
      end

      # @note **OPTIONAL**
      #
      # Gets called right before killing the plugin and should return state data
      # to be {Arachni::State::Plugins#store stored} and passed to {#restore}.
      # 在杀死插件之前被调用，并且应该将状态数据返回到{Arachni::State::Plugins#store stored}并传递给{#restore}。
      #
      # @return   [Object]    State to store.
      #
      # @see #restore
      # @abstract
      def suspend
      end

      # Pauses the {#framework}.
      def framework_pause
        @pause_id ||= framework.pause(false)
      end

      # Aborts the {#framework}.
      def framework_abort
        Thread.new do
          framework.abort
        end
      end

      # Resumes the {#framework}.
      def framework_resume
        return if !@pause_id
        framework.resume @pause_id
      end

      # @note **OPTIONAL**
      #
      # Only used when in Grid mode.
      # 仅在集群模式下使用。
      #
      # Should the plug-in be distributed across all instances or only run by the
      # master prior to any distributed operations?
      # 插件是应该分布在所有实例上还是仅在任何分布式操作之前由主服务器运行？
      #
      # For example, if a plug-in dynamically modifies the framework options in
      # any way and wants these changes to be identical across instances this
      # method should return `false`.
      # 例如，如果插件以任何方式动态修改框架选项，并希望这些更改在实例之间相同，则此方法应返回“false”。
      def self.distributable?
        @distributable ||= false
      end

      # Should the plug-in be distributed across all instances or only run by the
      # master prior to any distributed operations?
      # 插件是应该分布在所有实例上还是仅在任何分布式操作之前由主服务器运行？
      def self.distributable
        @distributable = true
      end

      # Should the plug-in be distributed across all instances or only run by the
      # master prior to any distributed operations?
      # 插件是应该分布在所有实例上还是仅在任何分布式操作之前由主服务器运行？
      def self.is_distributable
        distributable
      end

      # @note **REQUIRED** if {.distributable?} returns `true` and the plugin
      #   {#register_results registers results}.
      #
      # Merges an array of results as gathered by the plug-in when ran by multiple
      # instances.
      # 合并由多个实例运行时插件收集的结果数组。
      def self.merge(results)
      end

      # Should return an array of plugin related gem dependencies.
      #
      # @return   [Array]
      def self.gems
        []
      end

      # REQUIRED
      #
      # @return   [Hash]
      # @abstract
      def self.info
        {
          name: "Abstract plugin class",
          description: %q{Abstract plugin class.},
          author: 'Tasos "Zapotek" Laskos <tasos.laskos@arachni-scanner.com>',
          version: "0.1",
          options: [
 #                       option name        required?       description                        default
                       # Options::Bool.new( 'print_framework', [ false, 'Do you want to print the framework?', false ] ),
                       # Options::String.new( 'my_name_is',    [ false, 'What\'s you name?', 'Tasos' ] ),
            ],
          # specify an execution priority group
          # plug-ins will be separated in groups based on this number
          # and lowest will be first
          #
          # if this option is omitted the plug-in will be run last
          #
          #   指定执行优先级组插件将根据此编号分组，最低编号将是第一个
          #   如果省略此选项，插件将最后运行
          priority: 0,
        }
      end

      def info
        self.class.info
      end

      def session
        framework.session
      end

      def http
        framework.http
      end

      def browser_cluster
        framework.browser_cluster
      end

      def with_browser(&block)
        browser_cluster.with_browser(&block)
      end

      # Registers the plugin's results to {Data::Plugins}.
      #
      # @param    [Object]    results
      def register_results(results)
        Data.plugins.store(self, results)
      end

      # Will block until the scan finishes.
      def wait_while_framework_running
        sleep 0.1 while framework.running?
      end
    end
  end
end
