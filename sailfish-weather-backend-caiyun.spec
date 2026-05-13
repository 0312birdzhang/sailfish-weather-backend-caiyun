Name:           sailfish-weather-backend-caiyun
Version:        1.0.0
Release:        1%{?dist}
Summary:        Caiyun backend for Sailfish Weather (Sailfish OS)
License:        GPLv3
URL:            https://github.com/0312birdzhang/sailfish-weather-backend-caiyun
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Packager:       0312birdzhang
Requires:       sailfish-weather

%description
This package provides the Caiyun backend for the Sailfish Weather application.
It installs QML backend files and icon PNGs required by the frontend.

%prep
%setup -q

%build
# no build step

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/share/sailfish-weather/backends
mkdir -p %{buildroot}/usr/share/themes/sailfish-default/silica/icons-monochrome

# copy QML backend files
cp -a OpenCaiyunBackend.qml %{buildroot}/usr/share/sailfish-weather/backends/ 2>/dev/null || true


# copy PNG icons (top-level or icons/ as shipped)
cp -a *.png %{buildroot}/usr/share/themes/sailfish-default/silica/icons-monochrome/ 2>/dev/null || true

%files
%defattr(-,root,root,-)
%doc README.md
/usr/share/sailfish-weather/backends/OpenCaiyunBackend.qml
/usr/share/themes/sailfish-default/silica/icons-monochrome/caiyun.png
/usr/share/themes/sailfish-default/silica/icons-monochrome/caiyun-small.png

%changelog
* Tue May 13 2026 0312birdzhang - 1.0.0-1
- Initial package
