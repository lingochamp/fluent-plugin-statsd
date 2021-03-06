require 'fluent/plugin/out_statsd'
require 'fluent/test'

RSpec.describe Fluent::StatsdOutput do
  let(:config) do
    %{
      type statsd
      namespace a.b.c
      batch_byte_size 512

      <metric>
        statsd_type timing
        statsd_key res_time
        statsd_val ${record['response_time']}
        statsd_rate 0.4
      </metric>
    }
  end
  let(:driver) { create_driver(config) }
  let(:statsd) { double('statsd', increment: true,
                                  timing: true,
                                  flush: true,
                                  'namespace=' => true,
                                  'batch_size=' => true,
                                  'batch_byte_size' => true)

               }
  let(:time) { Time.now.utc }

  before :all do
    Fluent::Test.setup
  end

  def create_driver(conf)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::StatsdOutput) {
    }.configure(conf)
  end

  def emit_events(events)
    events.each {|e| driver.emit(e, time) }
  end


  it 'should call statsd with events data' do
    allow(Statsd).to receive(:new).and_return(statsd)

    expect(statsd).to receive(:namespace=).with('a.b.c')
    expect(statsd).to receive(:batch_size=).with(nil)
    expect(statsd).to receive(:batch_byte_size=).with(512)

    expect(statsd).to receive(:timing).with('res_time', 102, sample_rate: 0.4).ordered
    expect(statsd).to receive(:timing).with('res_time', 105, sample_rate: 0.4).ordered
    expect(statsd).to receive(:timing).with('res_time', 112, sample_rate: 0.4).ordered
    expect(statsd).to receive(:timing).with('res_time', 125, sample_rate: 0.4).ordered

    emit_events([
      {'response_time' => 102, 'status' => '200'},
      {'response_time' => 105, 'status' => '200'},
      {'response_time' => 112, 'status' => '400'},
      {'response_time' => 125, 'status' => '500'}
    ])

    driver.run
  end
end
