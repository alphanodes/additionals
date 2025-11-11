# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)
require 'benchmark'

class ScrubberBenchmarkTest < Additionals::TestCase
  def setup
    skip 'Benchmark test - run with BENCHMARK=1' unless ENV['BENCHMARK']
  end

  # Generate test content with varying complexity
  def small_content
    <<~MARKDOWN
      # Test Document

      This is a :smile: test with some :heart: emojis.
      Regular text without emojis.
      More text with :+1: and :tada: emojis.

      ```ruby
      # Code block that should be skipped
      puts ":smile: should not be converted in code"
      ```

      Final paragraph with :wave: emoji.
    MARKDOWN
  end

  def medium_content
    # 3x the small content
    content = small_content
    "#{content}\n\n#{content}\n\n#{content}"
  end

  def large_content
    # 10x the medium content (30x the small content)
    content = medium_content
    Array.new(10) { content }.join("\n\n")
  end

  def very_large_content
    # 100x the small content
    content = small_content
    Array.new(100) { content }.join("\n\n")
  end

  # Helper to parse markdown and return Nokogiri document
  def parse_markdown(text)
    html = Redmine::WikiFormatting::CommonMark::Formatter.new(text).to_html
    Loofah.fragment html
  end

  # Count text nodes in document
  def count_text_nodes(doc)
    count = 0
    doc.traverse do |node|
      count += 1 if node.text?
    end
    count
  end

  # Benchmark a scrubber with given content
  def benchmark_scrubber(scrubber_class, content_name, content, iterations: 100)
    doc = parse_markdown content
    text_node_count = count_text_nodes doc

    puts "\n#{scrubber_class.name} - #{content_name} (#{text_node_count} text nodes):"

    time = Benchmark.measure do
      iterations.times do
        # Create fresh document for each iteration
        fresh_doc = parse_markdown content
        scrubber = scrubber_class.new
        fresh_doc.scrub! scrubber
      end
    end

    avg_time_ms = (time.real * 1000) / iterations
    puts format('  %<iterations>d iterations: %<avg>.2f ms average (total: %<total>.2f ms)',
                iterations: iterations, avg: avg_time_ms, total: time.real * 1000)

    avg_time_ms
  end

  def test_emoji_scrubber_performance
    puts "\n#{'=' * 80}"
    puts 'EMOJI SCRUBBER PERFORMANCE BENCHMARK'
    puts '=' * 80

    scrubber = Additionals::WikiFormatting::CommonMark::EmojiScrubber

    results = {}
    results[:small] = benchmark_scrubber scrubber, 'Small content', small_content, iterations: 100
    results[:medium] = benchmark_scrubber scrubber, 'Medium content (3x)', medium_content, iterations: 50
    results[:large] = benchmark_scrubber scrubber, 'Large content (30x)', large_content, iterations: 10
    results[:very_large] = benchmark_scrubber scrubber, 'Very large content (100x)', very_large_content, iterations: 5

    # Check scaling
    puts "\nScaling Analysis:"
    puts format('  Medium vs Small: %.1fx slower', results[:medium] / results[:small])
    puts format('  Large vs Small: %.1fx slower', results[:large] / results[:small])
    puts format('  Very Large vs Small: %.1fx slower', results[:very_large] / results[:small])

    # Redmine Core had 29.4x slowdown for 3x content before fix
    # After fix it was close to linear scaling
    puts "\nComparison to Redmine Core Issue #43446:"
    puts '  Before fix: 3x content was ~29.4x slower'
    puts '  After fix: 3x content was ~3-4x slower (near linear)'
    puts format('  Our result: 3x content is %.1fx slower', results[:medium] / results[:small])

    if (results[:medium] / results[:small]) > 10.0
      puts "\n⚠️  WARNING: Non-linear scaling detected! Performance optimization needed."
    else
      puts "\n✅ Scaling looks reasonable (< 10x for 3x content)"
    end
  end

  def test_smiley_scrubber_performance
    puts "\n#{'=' * 80}"
    puts 'SMILEY SCRUBBER PERFORMANCE BENCHMARK'
    puts '=' * 80

    scrubber = Additionals::WikiFormatting::CommonMark::SmileyScrubber

    # Use content with smileys instead of emoji codes
    smiley_content = small_content.gsub(':smile:', ':)').gsub(':heart:', '<3').gsub(':+1:', '(y)')

    results = {}
    results[:small] = benchmark_scrubber scrubber, 'Small content', smiley_content, iterations: 100
    results[:medium] = benchmark_scrubber scrubber, 'Medium content (3x)', smiley_content * 3, iterations: 50
    results[:large] = benchmark_scrubber scrubber, 'Large content (30x)', smiley_content * 30, iterations: 10
    results[:very_large] = benchmark_scrubber scrubber, 'Very large content (100x)', smiley_content * 100, iterations: 5

    # Check scaling
    puts "\nScaling Analysis:"
    puts format('  Medium vs Small: %.1fx slower', results[:medium] / results[:small])
    puts format('  Large vs Small: %.1fx slower', results[:large] / results[:small])
    puts format('  Very Large vs Small: %.1fx slower', results[:very_large] / results[:small])

    if (results[:medium] / results[:small]) > 10.0
      puts "\n⚠️  WARNING: Non-linear scaling detected! Performance optimization needed."
    else
      puts "\n✅ Scaling looks reasonable (< 10x for 3x content)"
    end
  end

  def test_both_scrubbers_combined
    puts "\n#{'=' * 80}"
    puts 'COMBINED SCRUBBERS PERFORMANCE BENCHMARK'
    puts '=' * 80
    puts '(Simulates real-world usage with both scrubbers enabled)'

    content = small_content
    doc = parse_markdown content
    text_node_count = count_text_nodes doc

    puts "\nSmall content (#{text_node_count} text nodes):"

    iterations = 100
    time = Benchmark.measure do
      iterations.times do
        fresh_doc = parse_markdown content
        emoji_scrubber = Additionals::WikiFormatting::CommonMark::EmojiScrubber.new
        smiley_scrubber = Additionals::WikiFormatting::CommonMark::SmileyScrubber.new
        fresh_doc.scrub! emoji_scrubber
        fresh_doc.scrub! smiley_scrubber
      end
    end

    avg_time_ms = (time.real * 1000) / iterations
    puts format('  %<iterations>d iterations: %<avg>.2f ms average',
                iterations: iterations, avg: avg_time_ms)
  end
end
