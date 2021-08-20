require "./spec_helper"

describe "GValue" do
  context "when used as in parameter" do
    it { Test::Subject.g_value_parameter(42).should eq("gint:42;") }
    it { Test::Subject.g_value_parameter(42_u32).should eq("guint:42;") }
    it { Test::Subject.g_value_parameter(42_i64).should eq("gint64:42;") }
    it { Test::Subject.g_value_parameter(42_u64).should eq("guint64:42;") }
    it { Test::Subject.g_value_parameter(65_i8).should eq("gchar:A;") }
    it { Test::Subject.g_value_parameter(42_u8).should eq("guchar:42;") }

    it { Test::Subject.g_value_parameter(1.23_f32).should eq("gfloat:1.23;") }
    it { Test::Subject.g_value_parameter(4.56).should eq("gdouble:4.56;") }

    it { Test::Subject.g_value_parameter("hey").should eq("gchararray:hey;") }
  end

  context "respond to as_* and as_*?" do
    it { GObject::RawGValue.new(5).as_s?.should eq(nil) }
    it { GObject::RawGValue.new(5).as_i32.should eq(5) }
    it { GObject::RawGValue.new("hi").as_s?.should eq("hi") }
    it { GObject::RawGValue.new("ho").as_s.should eq("ho") }
    it do
      expect_raises(TypeCastError) { GObject::RawGValue.new("ho").as_f }
    end
  end

  context "when used as out parameter" do
    it "works" do
      res = Test::Subject.g_value_by_out_parameter
      typeof(res).should eq(GObject::Value)
      res.is_a?(Int32).should eq(true)
      res.should eq(42)
    end
  end

  context "when used as parameter in an array" do
    it "can convert integer types" do
      res = Test::Subject.new.array_of_g_values(-12, 34_u32, 56_i64, 78_u64, 66_i8, 10_u8)
      res.should eq("gint:-12;guint:34;gint64:56;guint64:78;gchar:B;guchar:10;")
    end

    it "can convert float types" do
      res = Test::Subject.new.array_of_g_values(3.14, 5.67_f32)
      res.should eq("gdouble:3.14;gfloat:5.67;")
    end

    it "can convert strings" do
      res = Test::Subject.new.array_of_g_values("hey", "ho")
      res.should eq("gchararray:hey;gchararray:ho;")
    end

    pending "can convert objects"
  end

  pending "when in a return value"
end
