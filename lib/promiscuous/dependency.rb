require 'fnv'

class Promiscuous::Dependency
  attr_accessor :internal_key, :version

  def initialize(*args)
    @internal_key = args.join('/')

    if @internal_key =~ /^[0-9]+$/
      @internal_key = @internal_key.to_i
      @hash = @internal_key
    else
      @hash = FNV.new.fnv1a_32(@internal_key)

      if Promiscuous::Config.hash_size.to_i > 0
        # We hash dependencies to have a O(1) memory footprint in Redis.
        # The hashing needs to be deterministic across instances in order to
        # function properly.
        @internal_key = @hash % Promiscuous::Config.hash_size.to_i
        @hash = @internal_key
      end
    end
  end

  def key(role)
    Promiscuous::Key.new(role).join(@internal_key)
  end

  def redis_node(distributed_redis=nil)
    distributed_redis ||= Promiscuous::Redis.master
    distributed_redis.nodes[@hash % distributed_redis.nodes.size]
  end

  def as_json(options={})
    @version ? [@internal_key, @version].join(':') : @internal_key
  end

  def self.parse(payload)
    case payload
    when /^(.+):([0-9]+)$/ then new($1).tap { |d| d.version = $2.to_i }
    when /^(.+)$/          then new($1)
    end
  end

  def to_s
    as_json.to_s
  end

  # We need the eql? method to function properly (we use ==, uniq, ...) in operation
  # XXX The version is not taken in account.
  def eql?(other)
    self.internal_key == other.internal_key
  end
  alias == eql?

  def hash
    self.internal_key.hash
  end
end
