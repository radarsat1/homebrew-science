# coding: utf-8
class Siconos < Formula
  desc "Modeling and simulation of nonsmooth dynamical systems"
  homepage "http://siconos.gforge.inria.fr"
  url "https://github.com/siconos/siconos/archive/4.0.0.tar.gz"
  sha256 "8b8b6b11d225e8d7f8fc2d068aa5e24701edaf364ce334939f8175df7d1868ae"
  head "https://github.com/siconos/siconos.git"

  depends_on "cmake" => :build
  depends_on :fortran => :build
  depends_on "swig" => :build
  depends_on "bullet"
  depends_on "boost"
  depends_on "homebrew/python/numpy"
  depends_on "homebrew/science/hdf5"
  depends_on "homebrew/science/vtk"

  depends_on :python if MacOS.version <= :snow_leopard

  # Unbrewed Python module dependencies
  # lxml
  resource "lxml" do
    url "https://files.pythonhosted.org/packages/11/1b/fe6904151b37a0d6da6e60c13583945f8ce3eae8ebd0ec763ce546358947/lxml-3.6.0.tar.gz"
    sha256 "9c74ca28a7f0c30dca8872281b3c47705e21217c8bc63912d95c9e2a7cac6bdf"
  end

  # h5py
  resource "h5py" do
    url "https://files.pythonhosted.org/packages/22/82/64dada5382a60471f85f16eb7d01cc1a9620aea855cd665609adf6fdbb0d/h5py-2.6.0.tar.gz"
    sha256 "b2afc35430d5e4c3435c996e4f4ea2aba1ea5610e2d2f46c9cae9f785e33c435"
  end

  def install
    # Install Python dependencies first
    ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python2.7/site-packages"
    %w[h5py lxml].each do |r|
      resource(r).stage do
        system "python", *Language::Python.setup_install_args(libexec/"vendor")
      end
    end

    # Install Siconos
    ENV.prepend_create_path "PYTHONPATH", libexec+"lib/python2.7/site-packages"
    system "cmake", ".", "-DIN_SOURCE_BUILD=ON", "-DWITH_BULLET=ON", *std_cmake_args
    system "make", "install"

    # Install executables and set Python path
    bin.install Dir[libexec/"bin/*"]
    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])
  end

  test do
    # executable
    system "#{bin}/siconos", "-h"
    # python modules
    system "python", "-c", "import siconos"
    system "python", "-c", "import siconos.kernel"
    system "python", "-c", "import siconos.kernel; siconos.kernel.SiconosVector()"
    system "python", "-c", "import siconos.mechanics"
    system "python", "-c", "import siconos.mechanics.joints"
    system "python", "-c", "import siconos.mechanics.contact_detection.bullet"
    system "python", "-c", "import siconos.control"
    system "python", "-c", "import siconos.io"
    # a C++ user program
    (testpath/"test.cpp").write <<-EOS.undent
    #include <SiconosKernel.hpp>
    int main() { SP::NonSmoothLaw nslaw(
      new NewtonImpactFrictionNSL(0.8, 0., 0.0, 3));
      return 0; }
    EOS
    system "siconos", "test.cpp"
    # a mechanicsIO script
    (testpath/"test.py").write <<-EOS.undent
      from siconos.mechanics.contact_detection.tools import Contactor
      from siconos.io.mechanics_io import Hdf5
      with Hdf5() as io:
        io.addConvexShape('Point', [(0,0,0)])
        io.addObject('point', [Contactor('Point')],
                     translation=[0,0,0],
                     velocity=[0,0,0,0,0,0],
                     mass=1)
      with Hdf5(mode='r+') as io:
        io.run(t0=0,T=1,h=1)
    EOS
    system "siconos", "test.py"
  end
end
