# lego-sbrick
A ruby gem library for interfacing with the LEGO® compatible Power Functions bluetooth SBrick (https://www.sbrick.com/)

## beta Build Instructions (NOT UPLOADED TO RUBYGEMS.ORG YET)
```ruby
git clone https://github.com/r1v3rrat/lego_sbrick.git
gem build lego_sbrick.gemspec
gem install lego_sbrick-0.0.1.gem

```
## requirements
- make sure you have bluetooth 4+, gatttool, know your bluethooth interface, and address of your sbrick
see https://social.sbrick.com/wiki/view/pageId/20/slug/linux-client-scripts
- I have only tested on ruby-2.3.0 but I'm sure lower versions will work

## Usage
```ruby
require 'rubygems'
require 'lego_sbrick'

# if you want the details on what is happening
Logging.logger.root.appenders = Logging.appenders.stdout
Logging.logger.root.level = :debug

# create object with your local interface and the remote address to the sbrick
b = SBrick.new("hci0","00:07:80:D0:57:C3")
puts b.version
puts b.uptime
puts b.resets
puts b.temperature
puts b.voltage
puts b.led_test

# who cares about voltage and tempature?  Hook up you sbrick using your car jumper cables and burn some plastic (don't actually do that)...
# control all 4 channels with a single command...

b.quick_drive([100,-50,:fw,:brake])
# channel 0 -> 100% power clockwise
# channel 1 -> 50% power counter clockwise
# channel 2 -> free wheel... cut power but do not brake
# channel 3 -> brake

# to keep things running use
b.spawn_keep_alive_thread
sleep 10
b.kill_keep_alive_thread!


```

## TODOS

- publish to github
- support other atrributes like watchdog
- eventually replace gatttol with https://github.com/sdalu/ruby-ble (however it requires newer libs than most distros have currently)

## other projects:
https://github.com/search?utf8=%E2%9C%93&q=sbrick&type=Repositories&ref=searchresults







