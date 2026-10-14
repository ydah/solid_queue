# frozen_string_literal: true

require "test_helper"
require_relative "plugin_testing"

class PluginAsyncTest < ActiveSupport::TestCase
  include PluginTesting

  test "restart while a job exceeds the shutdown timeout" do
    StoreResultJob.perform_later("unfinished", pause: SolidQueue.shutdown_timeout + 30.seconds)
    wait_for(timeout: 5.seconds) { JobResult.exists?(value: "unfinished", status: "started") }
    previous_process_ids = SolidQueue::Process.pluck(:id)

    signal_process(@pid, :SIGUSR2)
    wait_for(timeout: SolidQueue.shutdown_timeout + 10.seconds) do
      SolidQueue::Process.where(id: previous_process_ids).none? && SolidQueue::Process.count == 5
    end

    StoreResultJob.perform_later("after restart")
    wait_for(timeout: 5.seconds) { JobResult.exists?(value: "after restart", status: "completed") }

    assert process_exists?(@pid)
    assert SolidQueue::Process.where(id: previous_process_ids).none?
  end

  private
    def solid_queue_mode
      :async
    end
end
