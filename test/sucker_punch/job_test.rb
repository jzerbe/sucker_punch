require 'test_helper'

module SuckerPunch
  class JobTest < Minitest::Test
    def teardown
      SuckerPunch::Queue.clear
    end

    def test_run_perform_delegates_to_instance_perform
      assert_equal "fake", FakeLogJob.__run_perform
    end

    def test_busy_workers_is_incremented_during_job_execution
      FakeSlowJob.perform_async
      sleep 0.1
      assert SuckerPunch::Queue::BUSY_WORKERS[FakeSlowJob.to_s].value > 0
    end

    def test_processed_jobs_is_incremented_on_successful_completion
      latch = Concurrent::CountDownLatch.new
      2.times{ FakeLogJob.perform_async }
      pool = SuckerPunch::Queue.find_or_create(FakeLogJob.to_s)
      pool.post { latch.count_down }
      latch.wait(0.5)
      assert SuckerPunch::Queue::PROCESSED_JOBS[FakeLogJob.to_s].value > 0
    end

    def test_failed_jobs_is_incremented_when_job_raises
      latch = Concurrent::CountDownLatch.new
      2.times{ FakeErrorJob.perform_async }
      pool = SuckerPunch::Queue.find_or_create(FakeErrorJob.to_s)
      pool.post { latch.count_down }
      latch.wait(0.5)
      assert SuckerPunch::Queue::FAILED_JOBS[FakeErrorJob.to_s].value > 0
    end

    private

    class FakeSlowJob
      include SuckerPunch::Job
      def perform
        sleep 0.3
      end
    end

    class FakeLogJob
      include SuckerPunch::Job
      def perform
        "fake"
      end
    end

    class FakeErrorJob
      include SuckerPunch::Job
      def perform
        raise "error"
      end
    end
  end
end

