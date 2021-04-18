# frozen_string_literal: true

# CryptoCompare wiki macros
# see https://www.cryptocompare.com/dev/widget/wizard/
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Create CryptoCompare information.
    {{cryptocompare(options)}}
  see https://additionals.readthedocs.io/en/latest/macros/#cryptocompare
      DESCRIPTION

      macro :cryptocompare do |_obj, args|
        raise 'The correct usage is {{cryptocompare(options)}}' if args.empty?

        _args, options = extract_macro_options args, :fsym, :fsyms, :tsym, :tsyms, :period, :type

        options[:fsym] = 'BTC' if options[:fsym].blank?
        options[:tsym] = 'EUR' if options[:tsym].blank?

        if options[:type].blank?
          widget_type = 'chart'
        else
          widget_type = options[:type]
          options.delete :type
        end

        case widget_type
        when 'chart'
          url = 'serve/v2/coin/chart'
        when 'news'
          options[:feedType] = 'CoinTelegraph' if options[:feedType].blank?
          url = 'serve/v1/coin/feed'
        when 'list'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :tsym
          url = 'serve/v1/coin/list'
        when 'titles'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :tsym
          url = 'serve/v1/coin/tiles'
        when 'tabbed'
          options[:fsyms] = Additionals.crypto_default options, :fsyms, 'BTC,ETH,LTC'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :fsym
          options.delete :tsym
          url = 'serve/v1/coin/multi'
        when 'header', 'header_v1'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :tsym
          url = 'serve/v1/coin/header'
        when 'header_v2'
          options[:fsyms] = Additionals.crypto_default options, :fsyms, 'BTC,ETH,LTC'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :fsym
          options.delete :tsym
          url = 'serve/v2/coin/header'
        when 'header_v3'
          options[:fsyms] = Additionals.crypto_default options, :fsyms, 'BTC,ETH,LTC'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR'
          options.delete :fsym
          options.delete :tsym
          url = 'serve/v3/coin/header'
        when 'summary'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :tsym
          url = 'serve/v1/coin/summary'
        when 'historical'
          url = 'serve/v1/coin/histo_week'
        when 'converter'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :tsym
          url = 'serve/v1/coin/converter'
        when 'advanced'
          options[:tsyms] = Additionals.crypto_default options, :tsyms, 'EUR,USD'
          options.delete :tsym
          url = 'serve/v3/coin/chart'
        else
          raise 'type is not supported'
        end

        params = options.map { |k, v| "#{k}=#{v}" }.join('&')
        render partial: 'wiki/cryptocompare',
               formats: [:html],
               locals: { url: "https://widgets.cryptocompare.com/#{url}?#{params}" }
      end
    end
  end

  def self.crypto_default(options, name, defaults)
    if options[name].blank?
      defaults
    else
      options[name].tr ';', ','
    end
  end
end
