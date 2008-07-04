
require "rubygems"
require "ruport"
require "ruport/util"
require 'scruffy'
  
RUBY_PATH = "#{ENV['HOME']}/dev/ruby"
SRC_PATH = "#{RUBY_PATH}/src"
BUILDS_PATH = "#{RUBY_PATH}/builds"
TESTS_PATH = "#{RUBY_PATH}/tests"
MATZ_RUBY_PATH = "#{SRC_PATH}/matzruby.git"
RUBYSPEC_PATH = "#{SRC_PATH}/rubyspec.git"
MSPEC_PATH = "#{SRC_PATH}/mspec.git/bin"

# RubyBuild objects encapsulate the information needed
# to checkout and build a tagged version of Ruby in
# a git clone of Ruby
# 
# Current limitations:
# 
# * only the 1.8 rubyspecs test are run.
# * only works with MRI Ruby
# 
# Example -- building and testing a development branch:
# 
#    rb = RubyBuild.new('ruby_1_8')
#    rb.build
#    rb.test
#    puts rb.report
#    
#    rubyspec tests for branch: ruby_1_8:
#    
#    testset: 1.8/language:
#    tests completed, files, examples, expectations, failures, errors
#    true, 47, 601, 1620, 0, 0
#    
#    testset: 1.8/library:
#    tests completed, files, examples, expectations, failures, errors
#    true, 1240, 3175, 10952, 15, 8
#    
#    testset: 1.8/core:
#    tests completed, files, examples, expectations, failures, errors
#    true, 1092, 4893, 17353, 0, 2
#
# Example -- building and testing a tagged branch:
#
#    rb = RubyBuild.new(186, 257)
#    rb.build
#    rb.test
#    puts rb.report
#    
#    
#    rubyspec tests for branch: ruby_v1_8_6_257:
#    summary:
#    tests completed, files, examples, expectations, failures, errors
#    true, 2379, 8537, 27777, 21, 3
#    
#    testset: 1.8/language:
#    tests completed, files, examples, expectations, failures, errors
#    true, 47, 601, 1620, 0, 0
#    
#    testset: 1.8/library:
#    tests completed, files, examples, expectations, failures, errors
#    true, 1240, 3071, 8863, 21, 3
#    
#    testset: 1.8/core:
#    tests completed, files, examples, expectations, failures, errors
#    true, 1092, 4865, 17294, 0, 0
# 
# == First setup up a local directory structure and clone the needed git repositories
#
# The following shell script creates a dir called 'ruby'
# in the current working directory and creates the directories
# 'src', 'builds', and 'tests' within that directory.
#
# The local git repositories are created in the 'src' directory.
# The local Ruby builds are created in the 'build' directory.
# Build and test results are cached in the 'tests' directory.
#
#   mkdir -p ruby/src
#   mkdir -p ruby/builds
#   mkdir -p ruby/tests
#   
#   src_path=`pwd`/ruby/src
#   builds_path=`pwd`/ruby/builds
#   
#   cd $src_path
#   
#   git clone git://github.com/rubyspec/matzruby.git matzruby.git
#   
#   git clone git://github.com/rubyspec/rubyspec.git rubyspec.git
#   rubyspec_path=`pwd`/rubyspec
#   
#   git clone git://github.com/rubyspec/mspec.git mspec.git
#   mspec_path=`pwd`/mspec.git/bin
#   chmod u+x $mspec_path/*
#
# Make sure the PATH constants in build_ruby.rb reflect
# your choices about where these working directories are placed.
#
# Currently Vladimir Sizikov's git clone of MRI Ruby located here: 
#
#   git://github.com/rubyspec/matzruby.git
#
# Is updated from the MRI svn repository hourly at 54 minutes past the hour.
#
# == How to create and test a Ruby patchlevel release in the shell manually.
#
# The following shell commands can be executed aftter running the 
# script above. They will first create a local git branch called 
# 'ruby_1_8_6_p114'. This code will be compiled and installed in
# builds/ruby_1_8_6_p114. Then the rubyspec tests will be run.
#
#   git checkout -b ruby_v1_8_6_p114 v1_8_6_114
#   autoconf && ./configure --prefix=$builds_path/ruby_1_8_6_p114
#   make && make install
#
# Uf you have already made the local branch ruby_v1_8_6_p114
# use this git command to check it out:
#
#   git checkout ruby_v1_8_6_p114
#
# The previous section is a manual version of what a 
# RubyBuild object instance performs.
#
# == More useful git info
#
# Pull any new tags added to the remote git repository:
#
#   git fetch -t
#
# Update the local git repository with all changes from the
# remote repository and merge the HEAD of the remote master
# branch with the local branch named master.
#
#   git checkout master
#   git pull
#
# Listing the remote branches. The branches are places
# where remote work is occuring
#
#    git branch -r
#      origin/HEAD
#      origin/master
#      origin/mvm
#      origin/ruby_1_3
#      origin/ruby_1_4
#      origin/ruby_1_6
#      origin/ruby_1_8
#      origin/ruby_1_8_5
#      origin/ruby_1_8_6
#      origin/ruby_1_8_7
#      origin/trunk
#
# When you checkout one of these branches it is very likely 
# that git will report:
#
#   Switched to branch "ruby_1_8"
#   Your branch is behind the tracked remote branch 'origin/ruby_1_8' by 52 commits,
#   and can be fast-forwarded.
#
# Perform a: 'git pull' to update your local branch
#
#
class RubyBuild
  #
  # The version of ruby that should be built or tested expressed as 
  # an integer or the name of a ruby branch expressed as a string""
  #
  # Integer forms of Ruby versions are represented like this:
  # (used when also specifying an integer patchlevel):
  #
  #   "1.8.6" => 186
  #   "1.9.1" => 191
  #
  #   "ruby_1_8" => the ruby branch ruby_1_8
  #
  attr_reader :version
  #
  # The patchlevel of ruby that should be built or tested 
  # expressed as an integer. 
  #
  # Ruby patchlevels are represented like this:
  #
  #   "114" => 114
  #   "257" => 257
  #
  attr_reader :patchlevel
  #
  # The actual tag used in the svn and git repositories.
  #
  # Examples:
  #
  #   "v1_8_6_114"
  #   "v1_8_6_257"
  #
  attr_reader :tag
  #
  # The name of the local branch in the git repository.
  # This is also the name of the external build directory.
  #
  # Examples:
  #
  #   tag "v1_8_6_114" => branch "ruby_v1_8_6_114"
  #   tag "v1_8_6_257" => branch "ruby_v1_8_6_257"
  #
  attr_reader :branch
  #
  # The total results sent to STDOUT when building ruby
  #
  attr_reader :build_report
  #
  # The response of the built ruby to: ruby -v
  #
  attr_reader :build_version
  #
  # The total results sent to STDOUT when running the rubyspec tests
  #
  attr_reader :rubyspec_reports
  #
  # The summary values in an array produced by running the rubyspec tests.
  #
  # The first value 'test_complete?' is a boolean which indictates whether all the test
  # were actually run. There are some combinations of the rubyspec tests
  # mspwc and Ruby patchlevels which cause an abort before completing
  # all the tests.
  #
  #   [test_completed?, files, examples, expectations, failures, errors]
  #
  attr_reader :rubyspec_summary
  #
  # The summary values for each set of test run as a hash with 
  # the key is the directory name of the test set
  #
  attr_reader :rubyspec_summaries
  #
  # Whether the rubyspec tests completed.
  #
  # Returns a three-valued 'boolean':
  #
  #   all the tests run => true
  #   not all the tests were run => false
  #   the tests haven't been run yet => nil
  #
  attr_reader :rubyspec_test_completion_status
  #
  # The number of rubyspec files processed by the rubyspec tests.
  #
  # Example: "2379"
  #
  attr_reader :rubyspec_files
  #
  # The number of rubyspec examples processed by the rubyspec tests.
  #
  # Example: "8511"
  #
  attr_reader :rubyspec_examples
  #
  # The number of rubyspec expectations processed by the rubyspec tests.
  #
  # Example: "27830"
  #
  attr_reader :rubyspec_expectations
  #
  # The number of rubyspec failures generated by the rubyspec tests.
  #
  # Example: 17"
  #
  attr_reader :rubyspec_failures
  #
  # The number of rubyspec errors generated by the rubyspec tests.
  #
  # Example: "3"
  #
  attr_reader :rubyspec_errors
  #
  # The path to the file where the test results are cached.
  #
  attr_reader :instance_cache_path
  #
  # The path to the directory where the ruby being tested will be built.
  #
  attr_reader :build_path
  #
  # The path to run the ruby that was built.
  #
  attr_reader :ruby_run_path
  #
  # The path to the run the mspec testing framework
  #
  attr_reader :mspec_run_path
  #
  # The path to the rubyspecs to run
  #
  attr_reader :rubyspec_path
  #
  # Pass in a Ruby version and patchlevel in integer form
  # when creating a new RubyBuild instance based on a tag.
  #
  # Examples for Ruby tags:
  #
  # Creating a RubyBuild object for building and testing tag: v1_8_6_v190
  #
  #   rb = RubyBuild.new(186, 190)
  #
  # Creating a RubyBuild object for building and testing tag: v1_9_0_2
  #
  #   rb = RubyBuild.new(190, 2)
  #
  # Examples for Ruby branches:
  #
  # If you want to build from an active branch like ruby_1_8, ruby_1_8_7 
  # or trunk pass in the branch name as string.
  #
  # Creating a RubyBuild object for building and testing branch: ruby_1_8
  #
  #   rb = RubyBuild.new('ruby_1_8')
  #
  # Creating a RubyBuild object for building and testing branch: ruby_1_8_7
  #
  #   rb = RubyBuild.new('ruby_1_8_7')
  #
  # Creating a RubyBuild object for building and testing branch: trunk
  #
  #   rb = RubyBuild.new('trunk')
  #
  def initialize(version, patchlevel=nil)
    @version = version
    @patchlevel = patchlevel
    @tag, @local_branch = generate_tag_and_local_branch
    @instance_cache_path = "#{TESTS_PATH}/#{@local_branch}.yml"
    check_for_cached_test_and_build_data
    @build_path = "#{BUILDS_PATH}/#{@local_branch}"
    @ruby_run_path = "#{@build_path}/bin/ruby"
    @mspec_run_path = "#{MSPEC_PATH}/mspec -t"
    @rubyspec_path = "#{RUBYSPEC_PATH}/1.8"
  end
  
  def generate_tag_and_local_branch
    if @patchlevel
      # assume we were passed integer representations of version and patchlevel
      tag = 'v' + @version.to_s.scan(/\d/).join('_') + '_' + @patchlevel.to_s
      [tag, "ruby_#{tag}"]
    else
      # else assume we were passed the name of a branch as a string
      [@version, @version]
    end
  end
  
  def check_for_cached_test_and_build_data
    if File.exists?(@instance_cache_path)
      saved_rb = YAML.load(File.read(@instance_cache_path))
      if saved_rb.version == @version && saved_rb.patchlevel == @patchlevel
        @build_report = saved_rb.build_report
        @build_version = saved_rb.build_version
        @rubyspec_reports = saved_rb.rubyspec_reports
        @rubyspec_summaries = saved_rb.rubyspec_summaries
        @rubyspec_test_completion_status = saved_rb.rubyspec_test_completion_status
        @rubyspec_files = saved_rb.rubyspec_files
        @rubyspec_examples = saved_rb.rubyspec_examples
        @rubyspec_expectations = saved_rb.rubyspec_expectations
        @rubyspec_failures = saved_rb.rubyspec_failures
        @rubyspec_errors = saved_rb.rubyspec_errors
      end
    end
  end
  
  def save
    File.open(@instance_cache_path, 'w') {|f| f.write YAML.dump(self)}
  end
  
  #
  # Checks out a local git branch of the tag
  # and builds that ruby. The compilation products
  # are saved in "builds/#{branch}"
  #
  # Pass RubyBuild#build(true) to force rebuilding
  # 
  def build(force=false)
    checkout_or_create_local_git_branch
    if !built? || force || @branch_updated
      build_and_install_local_branch
    else
      puts "\n#{@tag} has already been built\n\n"
    end
  end

  def built?
    File.exists?(@build_path)
  end
  #
  # Runs the rubyspec 1.8/ tests
  #
  # Pass RubyBuild#test(true) to force re-testing
  # 
  def test(force=false)
    if built?
      if !tested? || force
        run_rubyspecs_on_local_branch
      else
        @rubyspec_summary
      end
    else
      puts "#{@tag} has not been built yet."
    end
  end

  # Returns a boolean:
  #
  #   tests have been run => true
  #   tests haven't been run yet => false
  #
  def tested?
    @rubyspec_summary ? true : false
  end
  
  #
  # Returns a three-valued 'boolean':
  #
  #   all the tests run => true
  #   not all the tests were run => false
  #   the tests haven't been run yet => nil
  #
  def tests_completed_ok?
    @rubyspec_test_completion_status
  end

  def checkout_or_create_local_git_branch
    @branch_updated = false
    if @local_branch == get_current_git_branch
      puts "\n#{@local_branch} already checked out\n"
    elsif @local_branches[/#{@local_branch}/]
      response = run_shell_command("git checkout #{@local_branch}")
      if response[/can be fast-forwarded/]
        run_shell_command("git pull")
        @branch_updated = true
      end
    else
      run_shell_command("git checkout -b #{@local_branch} #{@tag}")
    end
  end

  def get_current_git_branch
    @local_branches = run_shell_command("git branch", false)
    @local_branches[/\* (.*)/, 1]
  end
  #
  # Builds the checked out ruby. The compilation 
  # products are saved in "builds/#{@local_branch}"
  # 
  def build_and_install_local_branch
    checkout_or_create_local_git_branch unless @local_branch == get_current_git_branch
    puts "\nconfiguring #{@local_branch}\n"
    @build_report = run_shell_command("autoconf && ./configure --prefix=#{@build_path}")
    puts "\nbuild and install #{@local_branch}:\n"
    @build_report << run_shell_command("make && make install")
    @build_version = run_shell_command("#{ruby_run_path} -v")
  end

  def run_rubyspecs_on_local_branch
    @rubyspec_reports = {}
    %w{core language library}.each do |testset|
      result = run_shell_command("unset RUBYOPT && #{@mspec_run_path} #{ruby_run_path} #{rubyspec_path}/#{testset}")
      @rubyspec_reports.merge!({"#{testset}" => result})
    end
    extract_summaries_from_rubyspecs_reports
    @rubyspec_test_completion_status = @rubyspec_summary[0]
    @rubyspec_files = @rubyspec_summary[1]
    @rubyspec_examples = @rubyspec_summary[2]
    @rubyspec_expectations = @rubyspec_summary[3]
    @rubyspec_failures = @rubyspec_summary[4]
    @rubyspec_errors = @rubyspec_summary[5]
    @rubyspec_summary
  end

  def rubyspec_reports_contents
    @rubyspec_reports.values.join("\n")
  end

  def run_shell_command(command, verbose=true)
    puts "\nrunning: #{command}\n" if verbose
    `#{command}`
  end

  def extract_summaries_from_rubyspecs_reports
    @rubyspec_summaries = {}
    @rubyspec_summary = [true, 0, 0, 0, 0, 0]
    @rubyspec_reports.each do |test, report|
      summary = extract_summary(report)
      @rubyspec_summaries.merge!({test => summary})
      @rubyspec_summary[0] = @rubyspec_summary[0] && summary[0]
      (1..5).each {|i| @rubyspec_summary[i] += summary[i]}
    end
  end
  
  def extract_summary(report)
    testblock = report[/^.*$/]
    expectations = testblock.length
    failures = testblock.scan(/F/).length
    if report[/Finished in (\d*\.\d*) seconds/, 1]
      re = /(\d*) files, (\d*) examples, (\d*) expectations, (\d*) failures, (\d*) errors/
      summary = re.match(report)
      [true, (1..5).collect {|m| summary[m].to_i}].flatten
      # [true, files, examples, expectations, failures, errors]
    else
      [false, 0, 0, expectations, failures, 0]
    end
  end

  def report
    report = "\n\nrubyspec tests for branch: #{@local_branch}:\n"
    report << "summary:\n"
    report << "tests completed, files, examples, expectations, failures, errors\n"
    report << "#{rubyspec_summary.join(', ')}\n"
    @rubyspec_reports.each_key do |test|
      report << "\ntestset: 1.8/#{test}:\n"
      report << "tests completed, files, examples, expectations, failures, errors\n"
      report << "#{@rubyspec_summaries[test].join(', ')}\n"
    end
    report
  end

  def full_report
    report = "\n\nrubyspec tests for branch: #{@local_branch}:\n"
    @rubyspec_reports.each_key do |test|
      report << "\ntestset: 1.8/#{test}:\n"
      report << "tests completed, files, examples, expectations, failures, errors\n"
      report << "#{@rubyspec_summaries[test].join(', ')}\n"
    end
    @rubyspec_reports.each do |test, rep|
      report << "\n------------------------ #{test} report summary ------------------------\n"
      report << "\ntestset: 1.8/#{test}:\n"
      report << "tests completed, files, examples, expectations, failures, errors\n"
      report << "#{@rubyspec_summaries[test].join(', ')}\n"
      report << "\n------------------------ #{test} report log ------------------------\n"
      report << rep
      report << "\n\n"
    end
    report
  end

end

class RubyBuildsReport
  #
  # A version of Ruby to test in integer form.
  #
  # Examples:
  #
  #   Ruby 1.9.0 => 190
  #   Ruby 1.8.7 => 187
  #   Ruby 1.8.6 => 186
  #
  attr_reader :version
  #
  # A range object that holds the first and last patchlevel
  # of Ruby patchlevels to report on. 
  #
  # Examples:
  #
  #   111..114
  #   114..257
  #
  attr_reader :report_range
  #
  # An array of RubyBuild objects that have been built and tested. 
  #
  attr_reader :ruby_builds
  #
  def initialize(version, report_range)
    @version = version
    @report_range = report_range
    @ruby_builds = []
    @report_range.each do |patch|
      rb = RubyBuild.new(@version, patch)
      rb.build
      rb.test
      rb.save
      @ruby_builds << rb
    end
  end
      
  def report
    report = "tag, tests completed, files, examples, expectations, failures, errors\n"
    @ruby_builds.each do |rb|
      report << ([rb.tag] << rb.rubyspec_summary).join(', ') + "\n"
    end
    report
  end 
end

class GraphReport < Ruport::Report
  renders_as_graph
  def renderable_data(format)
    graph = Graph(rbreport.report_range.to_a)
    graph.series(rbreport.ruby_builds.collect {|rb| rb.rubyspec_failures }, "rubyspec failures") 
    return graph
  end
end

# rbreport = RubyBuildsReport.new(230..257)
# 
# GraphReport.generate do |r| 
#     r.save_as("rubyspec_test_ruby_patchelevels_190_192.svg", :template => :graph)
# end
  
# (241..254).each do |patch|
#   build_and_install_local_branch(186, patch)
# end
# 
# def get_summaries(range)
#   reports = []
#   summaries = []
#   range.each do |patch|
#     reports << [patch, run_rubyspecs_on_local_branch(186, patch)]
#     summaries << [patch, extract_summary_from_rubyspecs_report(reports.last[1])]
#   end
#   summaries
# end

# 
# puts run_rubyspecs_on_local_branch(186, 114)