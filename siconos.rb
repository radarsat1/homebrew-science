# coding: utf-8
class Siconos < Formula
  desc "Modeling and simulation of nonsmooth dynamical systems"
  homepage "http://siconos.gforge.inria.fr"
  url "https://github.com/siconos/siconos/archive/4.0.0.tar.gz"
  sha256 "8b8b6b11d225e8d7f8fc2d068aa5e24701edaf364ce334939f8175df7d1868ae"
  head "https://github.com/siconos/siconos.git"

  depends_on "cmake" => :run
  depends_on :fortran
  depends_on "swig" => :build
  depends_on "bullet"
  depends_on "boost"
  depends_on "numpy"
  depends_on "scipy"
  depends_on "hdf5"
  depends_on "vtk"

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

  # cython needed by h5py
  resource "cython" do
    url "https://files.pythonhosted.org/packages/b1/51/bd5ef7dff3ae02a2c6047aa18d3d06df2fb8a40b00e938e7ea2f75544cac/Cython-0.24.tar.gz"
    sha256 "6de44d8c482128efc12334641347a9c3e5098d807dd3c69e867fa8f84ec2a3f1"
  end

  # six needed by h5py
  resource "six" do
    url "https://files.pythonhosted.org/packages/4e/aa/73683ca0c4237891e33562e3f55bcaab972869959b97b397637519d92035/six-1.4.1.tar.gz"
    sha256 "f045afd6dffb755cc0411acb7ce9acc4de0e71261d4b5f91de2e68d9aa5f8367"
  end

  def install
    def pyver
      Language::Python.major_minor_version "python"
    end
    pyinst = libexec/"vendor/lib/python#{pyver}/site-packages"

    # Install Python dependencies first
    ENV.prepend_create_path "PYTHONPATH", pyinst
    %w[cython six h5py lxml].each do |r|
      resource(r).stage do
        system "python", *Language::Python.setup_install_args(libexec/"vendor")
      end
    end

    # Install Siconos
    ENV.prepend_create_path "PYTHONPATH", pyinst
    system "cmake", ".", "-DIN_SOURCE_BUILD=ON", "-DWITH_BULLET=ON", *std_cmake_args
    system "make", "install"

    # Install executables and set Python path
    bin.install Dir[libexec/"bin/*"]
    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])

    # Make Python module dependencies available
    dest_path = lib/"python#{pyver}/site-packages"
    dest_path.mkpath
    ENV.prepend_create_path "PYTHONPATH", pyinst
    (dest_path/"homebrew-siconos.pth").write "#{pyinst}\n"
  end

  test do
    # executable
    system "#{bin}/siconos", "-h"
    # python modules
    system "python", "-B", "-c", "import siconos"
    system "python", "-B", "-c", "import siconos.kernel"
    system "python", "-B", "-c", "import siconos.kernel; siconos.kernel.SiconosVector()"
    system "python", "-B", "-c", "import siconos.mechanics"
    system "python", "-B", "-c", "import siconos.mechanics.joints"
    system "python", "-B", "-c", "import siconos.mechanics.contact_detection.bullet"
    system "python", "-B", "-c", "import siconos.control"
    system "python", "-B", "-c", "import siconos.io"
    # a C++ user program
    (testpath/"test.cpp").write <<-EOS.undent
    #include <SiconosKernel.hpp>
    int main() { SP::NonSmoothLaw nslaw(
      new NewtonImpactFrictionNSL(0.8, 0., 0.0, 3));
      return 0; }
    EOS
    system "#{bin}/siconos", (testpath/"test.cpp")
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
    system "siconos", (testpath/"test.py")
  end
end
