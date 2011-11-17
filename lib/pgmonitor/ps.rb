require 'eventmachine'

require 'pgmonitor/usagedata'

module Pgmonitor::PS
  extend self

  def log(level, *args)
    if level == :debug
      $stderr.puts(*args) if ::Pgmonitor.debug?
    else
      if level == :error
        $stderr.puts(*args)
      else
        $stdout.puts(*args)
      end
    end
  end

  def processes(&blk)
    ::EM.system("ps h -u postgres -o user,pid,ni,cp,rss,command") do |output, status|
      data = []
      output.split("\n").each do |line|
        d = line_to_data(line)
        data << d if d
      end
      blk.call(data)
    end
  end

  @@last_renice = Time.now

  def need_to_renice?
    @@last_renice < Time.now - 60
  end

  def renice(&blk)
    unless need_to_renice?
      blk.call if blk
      return
    end

    databases = ::Pgmonitor::UsageData.avg
    databases.delete('postgres')
    databases.each do |db, d|
      if d['cpu'] > 200
        d['nice'] = 19
      elsif d['cpu'] > 100
        d['nice'] = 15
      else
        d['nice'] = 5
      end

      # if the number of connections is "high"
      # you're probably stressing the machine just by
      # having open connections
      if d['connections'] > 20 && d['nice'] < 15
        d['nice'] = 15
      end
    end

    databases.each do |db, d|
      log(:notice, "usage db_name='#{db}' cpu=#{d['cpu']} mem=#{d['mem']} nice=#{d['nice']} elapsed=#{d['elapsed_time']} connections=#{d['connections']}#{::Pgmonitor.log_items}")
    end

    processes do |psdata|
      @@last_renice = Time.now
      psdata.each do |ps|
        db = ps['database']
        next unless databases.has_key?(db)
        nice = databases[db]['nice']
        next if nice == ps['nice'].to_i

        log(:debug, "renicing db_name='#{db}' pid=#{ps['pid']} from=#{ps['nice']} to=#{nice}")
        `renice #{nice} -p #{ps['pid']} > /dev/null 2>&1`
      end

      renice_writer_process

      EM.next_tick(&blk) if blk
    end
  end

  def queue
    EM.add_timer(::Pgmonitor.delay) { ::Pgmonitor::PS.run }
  end

  def run
    processes do |data|
      ::Pgmonitor::PS.scrape(data) { renice { ::Pgmonitor::PS.queue } }
    end
  end

  def scrape(data, &blk)
    t1 = Time.now
    cdata = cummulate_data(data, t1)
    add_cummulative_data(cdata)
    blk.call
  end

  def add_cummulative_data(cdata)
    cdata.each do |database, data|
      ::Pgmonitor::UsageData.add(database, data)
    end
    ::Pgmonitor::UsageData.clean
  end

  def cummulate_data(data, timeslice)
    databases = {}
    data.each do |d|
      db = d['database']
      databases[db] ||= {
        'pids' => [],
        'cpu' => 0,
        'mem' => 0,
        'connections' => 0,
        'sources' => [],
        'timeslice' => timeslice,
      }

      databases[db]['pids'] << d['pid']
      databases[db]['cpu'] += d['cpu'].to_i
      databases[db]['mem'] += d['mem'].to_i
      databases[db]['connections'] += 1
      databases[db]['sources'] << "#{d['ip']}:#{d['port']}"
    end
    databases
  end

  def line_to_data(line)
    tokens = line.split(/\s+/)

    pdata = { }
    pdata['user'] = tokens.shift
    pdata['pid']  = tokens.shift
    pdata['nice'] = tokens.shift
    pdata['cpu']  = tokens.shift
    pdata['mem']  = tokens.shift
    command = tokens.join(' ')

    data = command_to_data(command)
    return unless data

    data.merge!(pdata)
    data
  end

  def command_to_data(command)
    regex = /^postgres: ([\w\d]+) ([\w\d]+) ((:?\d{1,3}\.){3}(?:\d{1,3}))\((\d+)\)/
    if m = regex.match(command)
      { 'database' => m[1], 'ip' => m[3], 'port' => m[4] }
    end
  end

  def renice_writer_process
    `ps aux | grep 'postgres: writer process' | awk '{print $2}' | xargs renice 4 -p > /dev/null 2>&1`
    `ps aux | grep 'postgres: wal writer process' | awk '{print $2}' | xargs renice 4 -p > /dev/null 2>&1`
  end
end
