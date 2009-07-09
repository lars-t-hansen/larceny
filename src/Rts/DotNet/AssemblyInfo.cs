using System.Reflection;
using System.Runtime.CompilerServices;
using System.Security.Permissions;

//
// General Information about an assembly is controlled through the following
// set of attributes. Change these attribute values to modify the information
// associated with an assembly.
//
[assembly: AssemblyTitle("")]
[assembly: AssemblyDescription("Scheme Runtime library")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("Northeastern University Programming Research Laboratory")]
[assembly: AssemblyProduct("Common Larceny")]
[assembly: AssemblyCopyright("2009")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]

//
// Version information for an assembly consists of the following four values:
//
//      Major Version
//      Minor Version
//      Build Number
//      Revision
//
// You can specify all the values or you can default the Revision and Build Numbers
// by using the '*' as shown below:

[assembly: AssemblyVersion("0.97.9999.*")]

//
// In order to sign your assembly you must specify a key to use. Refer to the
// Microsoft .NET Framework documentation for more information on assembly signing.
//
// Use the attributes below to control which key is used for signing.
//
// Notes:
//   (*) If no key is specified, the assembly is not signed.
//   (*) KeyName refers to a key that has been installed in the Crypto Service
//       Provider (CSP) on your machine. KeyFile refers to a file which contains
//       a key.
//   (*) If the KeyFile and the KeyName values are both specified, the
//       following processing occurs:
//       (1) If the KeyName can be found in the CSP, that key is used.
//       (2) If the KeyName does not exist and the KeyFile does exist, the key
//           in the KeyFile is installed into the CSP and used.
//   (*) In order to create a KeyFile, you can use the sn.exe (Strong Name) utility.
//       When specifying the KeyFile, the location of the KeyFile should be
//       relative to the project output directory which is
//       %Project Directory%\obj\<configuration>. For example, if your KeyFile is
//       located in the project directory, you would specify the AssemblyKeyFile
//       attribute as [assembly: AssemblyKeyFile("..\\..\\mykey.snk")]
//   (*) Delay Signing is an advanced option - see the Microsoft .NET Framework
//       documentation for more information on this.
//
// [assembly: AssemblyDelaySign(false)]
//[assembly: AssemblyKeyFile("..\\..\\mykey.snk")]
// [assembly: AssemblyKeyName("")]

// Permissions
// These all indicate that we do not *require* any particular permission
// but that we may use any permission that happens to be granted.
// That is, Scheme will not refuse to run if you don't allow it to do file IO,
// but we do not guarantee that we won't ask.

// Since CommonLarceny is a language system, there doesn't seem to be any option other
// than this.
//[assembly: EnvironmentPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: FileDialogPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: FileIOPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: IsolatedStorageFilePermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: ReflectionPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: RegistryPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: SecurityPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: SiteIdentityPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: StrongNameIdentityPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: UIPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: UrlIdentityPermission (SecurityAction.RequestOptional, Unrestricted = true)]
//[assembly: ZoneIdentityPermission (SecurityAction.RequestOptional, Unrestricted = true)]
