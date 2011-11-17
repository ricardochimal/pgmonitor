module Pgmonitor::UsageData
  extend self
  @@data = {}

  def data
    @@data
  end

  #     @@data = {
  #        mem and cpu are aggregated among all the different postgres processes
  #             'database' => [ { 'mem' => '50024', 'cpu' => '05', 'connections' => 1, 'timeslice' => Time.now } ]
  #     }

  def add(database, data)
    @@data[database] ||= []
    @@data[database] << data
  end

  def clean
    cutoff = Time.now - 60*2
    @@data.each do |database, d|
      d.reject! { |d| d['timeslice'] < cutoff }
      @@data.delete(database) if d.size == 0
    end
  end

  def avg
    avgs = {}
    @@data.each do |database, d|
      next if d.size == 0
      avgs[database] = avg_data(d)
    end
    avgs.each { |db, d| avgs.delete(db) if db.nil? or d.nil? }
    avgs
  end

  def avg_data(mdata)
    fields = %w[mem cpu connections]
    avgs = {}
    num = mdata.size
    fields.each do |field|
      avgs[field] ||= 0
      mdata.each do |d|
        avgs[field] += d[field]
      end
      avgs[field] = avgs[field] / num
    end

    avgs['timeslice'] = mdata.collect { |d| d['timeslice'] }.sort
    t1 = avgs['timeslice'].first
    t2 = avgs['timeslice'].last
    avgs['elapsed_time'] = (t2 - t1).to_i
    avgs
  end
end
