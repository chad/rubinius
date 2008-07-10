# Executed by dev-tramp only!

prefix = File.dirname ENV['BUILDDIR']
my_name = ENV['PROGNAME']

my_name = "rubinius" if my_name == "dev-tramp"

real = File.join(prefix, 'shotgun/rubinius.local.bin')

# Setup all the crazy library path stuff so that librubinus is picked
# up properly.

@prefix = prefix

def set_env(name)
  addition = "#{@prefix}/shotgun/lib"

  if cur = ENV[name]
    ENV[name] = "#{addition}:#{cur}"
  else
    ENV[name] = addition
  end
end

set_env 'LD_LIBRARY_PATH'
set_env 'LD_LIBRARY_PATH_64'
set_env 'SHLIB'
set_env 'LIBPATH'
set_env 'PATH'
set_env 'DYLD_LIBRARY_PATH'
set_env 'DYLD_FALLBACK_LIBRARY_PATH'

ENV['RBX_IN_BUILDDIR'] = "1"

ENV['RBX_PREFIX'] = "#{prefix}/"

unless ENV['RBX_BOOTSTRAP']
  ENV['RBX_BOOTSTRAP'] = "#{prefix}/runtime/bootstrap"
end

unless ENV['RBX_COMMON']
  ENV['RBX_COMMON'] = "#{prefix}/runtime/common"
end

unless ENV['RBX_DELTA']
  ENV['RBX_DELTA'] = "#{prefix}/runtime/delta"
end

unless ENV['RBX_PLATFORM']
  ENV['RBX_PLATFORM'] = "#{prefix}/runtime/platform"
end

unless ENV['RBX_LOADER']
  ENV['RBX_LOADER'] = "#{prefix}/runtime/loader.rbc"
end

unless ENV['RBX_PLATFORM_CONF']
  ENV['RBX_PLATFORM_CONF'] = "#{prefix}/runtime/platform.conf"
end

ENV['RUBYLIB'] = %w(lib stdlib).map { |dir| File.join(prefix, dir) }.join(":")

if ARGV[0] == "--gdb"
  ARGV.shift

  ENV['PATH'] = "#{prefix}/shotgun:#{ENV['PATH']}"
  args = ['-x', "#{prefix}/shotgun/gdbcommands"]
  if `uname -s` == "Darwin" and `uname -r`.split(".")[0].to_i < 9
    args << '-x' << "#{prefix}/shotgun/gdbenvironment"
  end
  args << '--args' << "/dev/null"

  exec "gdb", *(args + ARGV)
elsif ARGV[0] == "--valgrind"
  ARGV.shift
  args = ['-v', real]
  exec 'valgrind', *(args + ARGV)
elsif ARGV[0] == "--shark"
  ARGV.shift
  puts "Starting up rubinius, then pausing for shark to start"
  pid = fork { sleep 5; exec real, *ARGV }
  exec "shark -o rbxshark -i -1 -a #{pid}"
elsif ARGV[0] == "--dtrace"
  ARGV.shift
  puts "Starting up rubinius, then pausing for dtrace to start"
  pid = fork { sleep 5; exec real, *ARGV }
  exec "dtrace -s #{ENV['SCRIPT']} -p #{pid}"
else
  exec [real, my_name], *ARGV
end
