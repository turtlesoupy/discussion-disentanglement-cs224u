require 'ostruct'
require 'set'

java_import org.joda.time.Seconds
java_import "edu.stanford.cs224u.disentanglement.structures.DataSets"

def walk(tree, parent=nil, depth=1, &block)
  block.call(tree, parent, depth)
  tree.getChildren().each do |child|
    walk(child, tree, depth+1, &block)
  end
end

class StatAcc
  attr_accessor :name, :averages, :total_counters, :square_total_counters
  def initialize(name, averages={})
    @name = name
    @averages = averages
    @total_counters = Hash.new(0)
    @square_total_counters = Hash.new(0)
  end

  def merge!(o)
    @averages.merge!(o.averages)
    [:total_counters, :square_total_counters].each do |m|
      o.send(m).each do |k,v|
        send(m)[k] += v
      end
    end
  end

  def add_total(name, val=1)
    @total_counters[name] += val
    @square_total_counters[name] += val * val
  end

  def print
    puts
    puts "*****#{@name} STATISTICS****"
    @total_counters.each do |name, total|
      puts "\tTotal #{name}:\t #{total}"
    end

    @averages.each do |average_name, total_name|
      mean = @total_counters[average_name].to_f / @total_counters[total_name]
      square_mean = @square_total_counters[average_name].to_f / @total_counters[total_name]
      sdev = Math.sqrt(square_mean - mean)
      puts sprintf("\t Mean #{average_name}:\t %.2f [%.2f]", mean, sdev)
    end
  end
end

def compute_stats(*datasets)
  aggregate_stats = datasets.map do |dataset|
    acc = StatAcc.new(dataset.to_s,
      "Nodes" => "Trees",
      "Children" => "Nodes",
      "Depth" => "Nodes",
      "Parent Lag" => "Nodes",
      "Body Length" => "Nodes",
      "Body Tokens" => "Nodes",
      "Percentage Unique Authors" => "Nodes",
      "Nodes Under Root" => "Trees",
      "Author Karma" => "Authors"
    )

    all_authors = Set.new

    dataset.read.each do |message_tree|
      acc.add_total "Trees"
      acc.add_total "Nodes Under Root", message_tree.root.children.size
      acc.add_total "Nodes", message_tree.linearize.size
      authors = Set.new
      walk(message_tree.root) do |node, parent, depth|
        authors.add(node.message.author_name)
        acc.add_total "Parent Lag", Seconds::seconds_between(parent.message.timestamp, node.message.timestamp).seconds unless parent.nil?
        acc.add_total "Children", node.children.size
        acc.add_total "Depth", depth
        acc.add_total "Body Length", node.message.body.length
        acc.add_total "Body Tokens", node.message.body_words.length
        all_authors << node.message.user if node.message.user
      end

      acc.add_total "Percentage Unique Authors", authors.length
    end
    acc.add_total "Authors", all_authors.length
    all_authors.each do |author|
      acc.add_total "Author Karma", author.karma
    end

    acc.print
    acc
  end.inject(StatAcc.new("AGGREGATED")) { |res, o| res.merge!(o); res }.print
end

#compute_stats(DataSets::ASK_REDDIT_TEST, DataSets::ASK_REDDIT_DEV, DataSets::ASK_REDDIT_TRAIN)
compute_stats(DataSets::ASK_HN_TEST, DataSets::ASK_HN_DEV, DataSets::ASK_HN_TRAIN)
