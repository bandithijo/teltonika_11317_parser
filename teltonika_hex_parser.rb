# 00000000000000568e01000001918b981e8b003faf5836fc4c9e32003401110d00002c350001000000000000000000012c3500290127050f4744313a53310000000000000000000f067cd9f46f1c8306020a7a0701550d01000e020bfe0100000059
# 00000000000000568e01000001918b981e8b003faf5836fc4c9e32003401110d00002c350001000000000000000000012c3500510127050f4744313a53310000000000000000000f067cd9f46f1c8306020a7a0701550d01000e020bfe27050f4744313a53320000000000000000000f067cd9f4defc1b06020a120701510d01000e020b120100000059
# 00000000000000568e01000001918b981e8b003faf5836fc4c9e32003401110d00002c350001000000000000000000012c3500790127050f4744313a53310000000000000000000f067cd9f46f1c8306020a7a0701550d01000e020bfe27050f4744313a53320000000000000000000f067cd9f4defc1b06020a120701510d01000e020b1227050f4744313a53330000000000000000000f067cd9f4ddfb8e06020a430701480d01000e020bab0100000059

require 'json'
require 'debug'

class TeltonikaHexParser
  def initialize(topic)
    @topic = topic
  end

  def parse_hex_data(hex_data)
    hex_data = hex_data.downcase

    parsed_sensors = []

    hex_index_8e = hex_data.index('8e')

    raise StandardError.new('Header 8e (Codec 8 Extended) are not found') if hex_index_8e.nil?

    timestamp = hex_data[hex_index_8e + 4, 16].to_i(16) / 1000.0

    sensor_data_start = hex_data.rindex('2c35')

    raise StandardError.new('Header 2c35 (AVL ID 11317) are not found') if sensor_data_start.nil?

    avl_id_11317_length = hex_data[sensor_data_start + 4, 4].to_i(16)
    avl_id_11317 = hex_data[(sensor_data_start + 4) + 4, (avl_id_11317_length * 2)]
    avl_id_11317.sub!('01', '')

    eye_sensor_data_header = avl_id_11317[0, 2]
    eye_sensor_data_length = (eye_sensor_data_header.to_i(16) + 1) * 2

    eye_sensors = avl_id_11317.scan(/.{1,#{eye_sensor_data_length}}/)

    eye_sensors.each do |eye_sensor|
      device_name = parsing_dong(eye_sensor, '050f')
      mac_addr = parsing_dong(eye_sensor, '0f06')
      temp = parsing_dong(eye_sensor, '0602')
      humidity = parsing_dong(eye_sensor, '0701')
      low_batt_indicator = parsing_dong(eye_sensor, '0d01')
      batt_voltage = parsing_dong(eye_sensor, '0e02')

      parsed_sensors << {
        hex_data_sensor: eye_sensor,
        device_name: [device_name].pack('H*').strip,
        mac_address: mac_addr.upcase.scan(/../).join(":"),
        temperature: (temp.to_i(16) * 0.01).round(2).to_s,
        humidity: humidity.to_i(16).to_s,
        low_batt_indicator: low_batt_indicator.to_i == 1,
        batt_voltage: (batt_voltage.to_i(16) * 0.001).round(2).to_s
      }
    end

    {
      timestamp: timestamp,
      topic: @topic,
      status: 'SUCCESS',
      sensors: parsed_sensors,
      hex_data: hex_data
    }.to_json
  rescue => e
    {
      timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S %z'),
      topic: @topic,
      status: 'FAILED',
      error: e,
      hex_data: hex_data
    }.to_json
  end

  private

    def parsing_dong(eye_sensor, header)
      data_length = eye_sensor[eye_sensor.index(header) + 2, 2].to_i(16)
      data = eye_sensor[eye_sensor.index(header) + 4, (data_length * 2)]
      return data
    rescue
      nil
    end
end

puts TeltonikaHexParser.new('306157816662968/data').parse_hex_data(ARGV.first)
