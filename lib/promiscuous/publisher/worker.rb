class Promiscuous::Publisher::Worker
  def start
    @thread ||= Thread.new { main_loop }
  end

  def stop
    @stop = true
    sleep 0.1
    @thread.kill
  end

  def main_loop
    loop do
      begin
        sleep Promiscuous::Config.recovery_interval

        break if @stop

        recover
      end
    end
  ensure
    ActiveRecord::Base.clear_active_connections!
  end

  def recover
    Promiscuous::Publisher::Operation::Base.expired.each do |lock|
      operation = Promiscuous::Publisher::Operation::Recovery.new(:operation_name => lock.data[:type])
      operation.recover!(lock)
      Promiscuous.info "[publish][recovery] #{lock.key} recovered"
    end
  rescue Promiscuous::Error::LockUnavailable
    # this is expected from within recovery
  rescue => e
    puts e; puts e.backtrace.join("\n")
    Promiscuous::Config.error_notifier.call(e)
  end
end

