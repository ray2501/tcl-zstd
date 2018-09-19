#
# spec file for package tcl-zstd
#

%define packagename zstd

Name:           tcl-zstd
Version:        0.1.6
Release:        0
License:        MIT
Summary:        Libzstd bindings for Tcl through Critcl
Url:            https://wiki.tcl.tk/48788
Group:          Development/Libraries/Tcl
Source:         %{name}-%{version}.tar.gz
BuildRequires:  tcl >= 8.4
BuildRequires:  gcc
BuildRequires:  tcllib
BuildRequires:  critcl >= 3.1.10
BuildRequires:  critcl-devel >= 3.1.10
BuildRequires:  libzstd-devel
BuildRequires:  libzstd1
Requires:       tcl >= 8.4
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
The package provides libzstd bindings for Tcl through Critcl.

%prep
%setup -q -n %{name}-%{version}

%build
critcl -pkg zstd.tcl

%install
mkdir -p %buildroot%tcl_archdir/%{packagename}%{version}
cp lib/zstd/critcl-rt.tcl %buildroot%tcl_archdir/%{packagename}%{version}
cp lib/zstd/pkgIndex.tcl %buildroot%tcl_archdir/%{packagename}%{version}
cp -r lib/zstd/linux-x86_64 %buildroot%tcl_archdir/%{packagename}%{version}

%files
%defattr(-,root,root)
%{tcl_archdir}/%{packagename}%{version}

