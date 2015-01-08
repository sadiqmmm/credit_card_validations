require_relative 'test_helper'


describe CreditCardValidations do


  let(:valid_numbers) {
    YAML.load_file File.join(File.dirname(__FILE__), 'fixtures/valid_cards.yml')
  }

  let(:invalid_numbers) {
    YAML.load_file File.join(File.dirname(__FILE__), 'fixtures/invalid_cards.yml')
  }

  before do
    CreditCardValidations.reload!
  end

  describe "MMI" do
    it "should detect issuer category" do
      d = detector(valid_numbers[:visa].first)
      d.issuer_category.must_equal CreditCardValidations::Mmi::ISSUER_CATEGORIES[d.number[0]]
    end
  end

  describe "Luhn#valid?" do
    let(:card_detector) {
      detector(valid_numbers[:unionpay].first)
    }
    it "should call Luhn.valid? once" do
      CreditCardValidations::Luhn.expects(:valid?).with(card_detector.number).once
      card_detector.valid?(:visa, :unionpay).must_equal true
    end

    it "should call Luhn.valid? twice" do
      CreditCardValidations::Luhn.expects(:valid?).with(card_detector.number).twice
      card_detector.valid?(:visa, :mastercard).must_equal false
    end

    it "should not call Luhn.valid?" do

      CreditCardValidations::Luhn.expects(:valid?).never
      card_detector.valid?(:unionpay).must_equal true
    end

  end


  it "should check luhn" do
    valid_numbers.each do |brand, card_numbers|
      if has_luhn_check_rule?(brand)
        card_numbers.each do |number|
          luhn_valid?(detector(number).number).must_equal true
        end
      end
    end
  end

  it "should check valid brand" do
    valid_numbers.each do |brand, card_numbers|
      card_numbers.each do |card_number|
        detector(card_number).send("#{brand}?").must_equal true
        detector(card_number).brand.must_equal brand
      end
    end
  end

  it "should check if card invalid" do
    invalid_numbers.each do |card_number|
      detector(card_number).valid?.must_equal false
      detector(card_number).brand.must_be_nil
      valid_numbers.keys.each do |brand|
        detector(card_number).send("#{brand}?").must_equal false
      end
    end
  end

  it "should support multiple brands for single check" do
    valid_numbers.slice(:visa, :mastercard).each do |key, value|
      detector(value.first).brand(:visa, :mastercard).must_equal key
    end

    valid_numbers.except(:visa, :mastercard).each do |_, value|
      detector(value.first).brand(:visa, :mastercard).must_be_nil
    end
  end

  it "should check if valid brand without arguments" do
    valid_numbers.each do |key, value|
      value.each do |card_number|
        detector(card_number).valid?(key).must_equal true
        assert detector(card_number).valid?.must_equal true
      end
    end
  end

  it "should not be valid? if wrong brand" do
    detector(valid_numbers[:visa].first).valid?(:mastercard).must_equal false
    detector(valid_numbers[:mastercard].first).valid?(:visa).must_equal false
  end

  it "should  be valid? if right brand" do
    detector(valid_numbers[:visa].first).valid?(:mastercard, :visa).must_equal true
    detector(valid_numbers[:visa].first).valid?(:mastercard, :amex).must_equal false
  end

  describe "ActiveModel Validator" do

    describe "Any brand" do
      let(:model) { AnyCreditCard.new }
      it "should accept any brand if valid" do
        valid_numbers.each do |_, numbers|
          card = model
          card.number = numbers.first
          card.valid?.must_equal true
        end
      end

      it "should reject invalid numbers" do
        invalid_numbers.each do |number|
          card = model
          card.number = number
          card.valid?.must_equal false
        end
      end

    end

    describe "Only Amex and Mestro brands" do
      let(:model) { CreditCard.new }

      it "should accept amex and maestro brand if valid" do
        valid_numbers.slice(:amex, :maestro) do |_, numbers|
          card = model
          card.number = numbers.first
          card.valid?.must_equal true
        end
      end

      it "should reject all other valid numbers" do
        valid_numbers.except(:amex, :maestro) do |_, numbers|
          card = model
          card.number = numbers.first
          card.valid?.must_equal false
        end

      end

    end


  end

  describe "String ext" do
    before do
      require 'credit_card_validations/string'
    end

    it "should allow detect brand" do
      valid_numbers[:mastercard].first.credit_card_brand.must_equal :mastercard
      valid_numbers[:mastercard].first.valid_credit_card_brand?(:mastercard).must_equal true
      valid_numbers[:mastercard].first.valid_credit_card_brand?(:visa, :amex).must_equal false
    end

  end


  describe "Dynamically adding brand" do
    before do
      CreditCardValidations::Detector.add_brand(:voyager, {length: 15, prefixes: '86'})
    end

    let(:voyager_number) {
      '869926275400212'
    }
    it "should validate number as voyager" do
      detector(voyager_number).valid?(:voyager).must_equal true
      detector(voyager_number).voyager?.must_equal true
      detector(voyager_number).visa?.must_equal false
      detector(voyager_number).mastercard?.must_equal false
      detector(voyager_number).brand.must_equal :voyager
    end
  end

  def luhn_valid?(number)
    CreditCardValidations::Luhn.valid?(number)
  end

  def detector(number)
    CreditCardValidations::Detector.new(number)
  end

  def has_luhn_check_rule?(key)
    !CreditCardValidations::Detector.brands[key].fetch(:options, {}).fetch(:skip_luhn, false)
  end

end