require 'spec_helper'

describe Hashie::Extensions::IndifferentAccess do
  class IndifferentHashWithMergeInitializer < Hash
    include Hashie::Extensions::MergeInitializer
    include Hashie::Extensions::IndifferentAccess

    class << self
      alias build new
    end
  end

  class IndifferentHashWithArrayInitializer < Hash
    include Hashie::Extensions::IndifferentAccess

    class << self
      alias build []
    end
  end

  class IndifferentHashWithTryConvertInitializer < Hash
    include Hashie::Extensions::IndifferentAccess

    class << self
      alias build try_convert
    end
  end

  class IndifferentHashWithDash < Hashie::Dash
    include Hashie::Extensions::IndifferentAccess
    property :foo
  end

  class IndifferentHashWithIgnoreUndeclaredAndPropertyTranslation < Hashie::Dash
    include Hashie::Extensions::IgnoreUndeclared
    include Hashie::Extensions::Dash::PropertyTranslation
    include Hashie::Extensions::IndifferentAccess
    property :foo, from: :bar
  end

  describe '#merge' do
    it 'indifferently merges in a hash' do
      indifferent_hash = Class.new(::Hash) do
        include Hashie::Extensions::IndifferentAccess
      end.new

      merged_hash = indifferent_hash.merge(cat: 'meow')

      expect(merged_hash[:cat]).to eq('meow')
      expect(merged_hash['cat']).to eq('meow')
    end

    it 'injects the resulting new Hash with IndifferentAccess' do
      hash = IndifferentHashWithMergeInitializer.new(
        :cat => 'meow',
        'dog' => { name: 'Mango', sound: 'woof' }
      )

      dog = hash[:dog]
      merged = dog.merge(foo: 'bar')

      expect(merged[:foo]).to eq('bar')
      expect(merged['foo']).to eq('bar')
    end
  end

  describe '#merge!' do
    it 'indifferently merges in a hash' do
      indifferent_hash = Class.new(::Hash) do
        include Hashie::Extensions::IndifferentAccess
      end.new

      indifferent_hash[:cat] = 'meow'

      expect(indifferent_hash[:cat]).to eq('meow')
      expect(indifferent_hash['cat']).to eq('meow')
    end
  end

  describe '#to_hash' do
    let(:indifferent_hash) { Class.new(::Hash) { include Hashie::Extensions::IndifferentAccess } }

    it 'returns a normal hash without indifference' do
      indifferent = indifferent_hash.new
      indifferent['cat'] = 'meow'

      subject = indifferent.to_hash

      expect(subject['cat']).to eq 'meow'
      expect(subject[:cat]).to be_nil
    end

    it 'maintains the #default_proc when set' do
      indifferent = indifferent_hash.new { |_hash, key| "Nothing here: #{key}" }

      subject = indifferent.to_hash

      expect(subject['babble']).to eq 'Nothing here: babble'
    end

    it 'maintains the #default when set' do
      indifferent = indifferent_hash.new(0)

      subject = indifferent.to_hash

      expect(subject['babble']).to eq 0
    end
  end

  describe 'when included in dash' do
    let(:params) { { foo: 'bar' } }
    subject { IndifferentHashWithDash.new(params) }

    it 'initialize with a symbol' do
      expect(subject.foo).to eq params[:foo]
    end
  end

  describe 'when overriding indifferent methods' do
    let(:indifferent_hash) do
      Class.new(::Hash) do
        include Hashie::Extensions::IndifferentAccess

        ALIASES = { cat: :grumpy }.freeze

        # Override writer to maintain alias of the given key
        def indifferent_writer(key, value)
          indifferent_value = indifferent_value(value)

          regular_writer convert_key(key),          indifferent_value
          regular_writer convert_key(ALIASES[key]), indifferent_value
        end
        alias_method :[]=, :indifferent_writer
      end.new
    end

    it '#indifferent_writer' do
      indifferent_hash[:cat] = 'meow'

      expect(indifferent_hash[:cat]).to eq('meow')
      expect(indifferent_hash['cat']).to eq('meow')

      expect(indifferent_hash[:grumpy]).to eq('meow')
      expect(indifferent_hash['grumpy']).to eq('meow')
    end

    it '#merge' do
      merged_hash = indifferent_hash.merge(cat: 'meow')

      expect(merged_hash[:cat]).to eq('meow')
      expect(merged_hash['cat']).to eq('meow')

      expect(merged_hash[:grumpy]).to eq('meow')
      expect(merged_hash['grumpy']).to eq('meow')
    end
  end

  describe 'when translating properties and ignoring undeclared' do
    let(:value) { 'baz' }

    subject { IndifferentHashWithIgnoreUndeclaredAndPropertyTranslation.new(params) }

    context 'and the hash keys are strings' do
      let(:params) { { 'bar' => value } }

      it 'sets the property' do
        expect(subject[:foo]).to eq value
      end
    end

    context 'and the hash keys are symbols' do
      let(:params) { { bar: 'baz' } }

      it 'sets the property' do
        expect(subject[:foo]).to eq value
      end
    end

    context 'and there are undeclared keys' do
      let(:params) { { 'bar' => 'baz', 'fail' => false } }

      it 'sets the property' do
        expect(subject[:foo]).to eq value
      end
    end
  end

  shared_examples_for 'hash with indifferent access' do
    it 'is able to access via string or symbol' do
      h = subject.build(abc: 123)
      expect(h[:abc]).to eq 123
      expect(h['abc']).to eq 123
    end

    describe '#values_at' do
      it 'indifferently finds values' do
        h = subject.build(:foo => 'bar', 'baz' => 'qux')
        expect(h.values_at('foo', :baz)).to eq %w[bar qux]
      end

      it 'returns the same instance of the hash that was set' do
        hash = {}
        h = subject.build(foo: hash)
        expect(h.values_at(:foo)[0]).to be(hash)
      end

      it 'returns the same instance of the array that was set' do
        array = []
        h = subject.build(foo: array)
        expect(h.values_at(:foo)[0]).to be(array)
      end

      it 'returns the same instance of the string that was set' do
        str = 'my string'
        h = subject.build(foo: str)
        expect(h.values_at(:foo)[0]).to be(str)
      end

      it 'returns the same instance of the object that was set' do
        object = Object.new
        h = subject.build(foo: object)
        expect(h.values_at(:foo)[0]).to be(object)
      end
    end

    describe '#fetch' do
      it 'works like normal fetch, but indifferent' do
        h = subject.build(foo: 'bar')
        expect(h.fetch(:foo)).to eq h.fetch('foo')
        expect(h.fetch(:foo)).to eq 'bar'
      end

      it 'returns the same instance of the hash that was set' do
        hash = {}
        h = subject.build(foo: hash)
        expect(h.fetch(:foo)).to be(hash)
      end

      it 'returns the same instance of the array that was set' do
        array = []
        h = subject.build(foo: array)
        expect(h.fetch(:foo)).to be(array)
      end

      it 'returns the same instance of the string that was set' do
        str = 'my string'
        h = subject.build(foo: str)
        expect(h.fetch(:foo)).to be(str)
      end

      it 'returns the same instance of the object that was set' do
        object = Object.new
        h = subject.build(foo: object)
        expect(h.fetch(:foo)).to be(object)
      end

      it 'yields with key name if key does not exists' do
        h = subject.build(a: 0)
        expect(h.fetch(:foo) { |key| ['default for', key] }).to eq ['default for', 'foo']
      end
    end

    describe '#delete' do
      it 'deletes indifferently' do
        h = subject.build(:foo => 'bar', 'baz' => 'qux')
        h.delete('foo')
        h.delete(:baz)
        expect(h).to be_empty
      end
    end

    describe '#key?' do
      let(:h) { subject.build(foo: 'bar') }

      it 'finds it indifferently' do
        expect(h).to be_key(:foo)
        expect(h).to be_key('foo')
      end

      %w[include? member? has_key?].each do |key_alias|
        it "is aliased as #{key_alias}" do
          expect(h.send(key_alias.to_sym, :foo)).to be(true)
          expect(h.send(key_alias.to_sym, 'foo')).to be(true)
        end
      end
    end

    describe '#update' do
      let(:h) { subject.build(foo: 'bar') }

      it 'allows keys to be indifferent still' do
        h.update(baz: 'qux')
        expect(h['foo']).to eq 'bar'
        expect(h['baz']).to eq 'qux'
      end

      it 'recursively injects indifference into sub-hashes' do
        h.update(baz: { qux: 'abc' })
        expect(h['baz']['qux']).to eq 'abc'
      end

      it 'does not change the ancestors of the injected object class' do
        h.update(baz: { qux: 'abc' })
        expect({}).not_to be_respond_to(:indifferent_access?)
      end
    end

    describe '#replace' do
      let(:h) { subject.build(foo: 'bar').replace(bar: 'baz', hi: 'bye') }

      it 'returns self' do
        expect(h).to be_a(subject)
      end

      it 'removes old keys' do
        [:foo, 'foo'].each do |k|
          expect(h[k]).to be_nil
          expect(h.key?(k)).to be_falsy
        end
      end

      it 'creates new keys with indifferent access' do
        [:bar, 'bar', :hi, 'hi'].each { |k| expect(h.key?(k)).to be_truthy }
        expect(h[:bar]).to eq 'baz'
        expect(h['bar']).to eq 'baz'
        expect(h[:hi]).to eq 'bye'
        expect(h['hi']).to eq 'bye'
      end
    end

    describe '#try_convert' do
      describe 'with conversion' do
        let(:h) { subject.try_convert(foo: 'bar') }

        it 'is a subject' do
          expect(h).to be_a(subject)
        end
      end

      describe 'without conversion' do
        let(:h) { subject.try_convert('{ :foo => bar }') }

        it 'is nil' do
          expect(h).to be_nil
        end
      end
    end

    with_minimum_ruby('2.5.0') do
      describe '#slice' do
        let(:h) { subject.build(foo: 'bar', baz: 'qux') }

        it 'indifferently slices the hash' do
          sliced_h = { 'foo' => 'bar' }
          expect(h.slice('foo')).to eq sliced_h
          expect(h.slice(:foo)).to eq sliced_h
        end
      end
    end

    with_minimum_ruby('3.0.0') do
      describe '#except' do
        let(:h) { subject.build(foo: 'bar', baz: 'qux') }

        it 'indifferently excepts keys from the hash' do
          sliced_h = { 'baz' => 'qux' }
          expect(h.except('foo')).to eq sliced_h
          expect(h.except(:foo)).to eq sliced_h
        end
      end
    end
  end

  describe 'with merge initializer' do
    subject { IndifferentHashWithMergeInitializer }
    it_should_behave_like 'hash with indifferent access'
  end

  describe 'with array initializer' do
    subject { IndifferentHashWithArrayInitializer }
    it_should_behave_like 'hash with indifferent access'
  end

  describe 'with try convert initializer' do
    subject { IndifferentHashWithTryConvertInitializer }
    it_should_behave_like 'hash with indifferent access'
  end
end
