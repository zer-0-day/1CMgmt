<#
    .SYNOPSIS
        
	    .DESCRIPTION
        Создание служебного пользователя 1С
	    .EXAMPLE
        Mgm1CMainMenu
    #>
function New-1CServiceUser {
    $username = "USR1CV8"  
    if (!(Get-LocalUser | Where-Object { $_.Name -match "USR1CV8" })) {
        # СОЗДАТЬ ПОЛЬЗОВАТЕЛЯ
        
        $password = Read-Host "Введите пароль пользователя USR1CV8" -AsSecureString
        
        #$compName=$env:computername
        # имя компа + имя пользователя
        # $fullnameuser = $compName +'\' + $username 
        New-LocalUser "$username" -Password $password -FullName "$username" -Description "Account for 1C:Enterprise 8 Server"
        #сохранить шифрованный пароль в файл
        $password | ConvertFrom-SecureString | Set-Content 'c:\passfile.txt'
        # предоставить пользователю права входа в качестве службы
        Add-Type @'
 using System;
 using System.Runtime.InteropServices;
 using System.Security.Principal;
 public class LsaUtility
 {
 [DllImport("advapi32.dll")]
 private static extern int LsaOpenPolicy(
   ref LSA_UNICODE_STRING sysName,
   ref LSA_OBJECT_ATTRIBUTES lsaObjectAttributes,
   int desiredAccess,
   out IntPtr lsaPolicyHandle);
 [DllImport("advapi32.dll", SetLastError = true)]
 private static extern int LsaAddAccountRights(
   IntPtr lsaPolicyHandle,
   IntPtr lsaAccountSid,
   LSA_UNICODE_STRING[] lsaUserRights,
   long count);
 [DllImport("advapi32.dll")]
 private static extern int LsaClose(IntPtr lsaObjectHandle);
 [DllImport("advapi32.dll")]
 private static extern int LsaNtStatusToWinError(int lsaStatus);
 public static long AddPrivilege(string sidString, string privilegeName)
 {
     LSA_UNICODE_STRING sysName = new LSA_UNICODE_STRING();
     LSA_OBJECT_ATTRIBUTES lsaAttributes = new LSA_OBJECT_ATTRIBUTES()
     {
         Length = 0,
         RootDirectory = IntPtr.Zero,
         ObjectName = new LSA_UNICODE_STRING(),
         Attributes = 0U,
         SecurityDescriptor = IntPtr.Zero,
         SecurityQualityOfService = IntPtr.Zero
     };
     int desiredAccess = 0x00F0FFF; // all access
     IntPtr lsaPolicyHandle = IntPtr.Zero;
     int status = LsaOpenPolicy(ref sysName, ref lsaAttributes, desiredAccess, out lsaPolicyHandle);
     int ntStatus = LsaNtStatusToWinError(status);
     if (ntStatus != 0)
     {
         Console.WriteLine("LsaOpenPolicy failed: " + ntStatus);
     }
     else
     {
         Console.WriteLine("LsaOpenPolicy succeeded");
         LSA_UNICODE_STRING[] lsaUserRights = new LSA_UNICODE_STRING[1]
         {
             new LSA_UNICODE_STRING()
         };
         lsaUserRights[0].lsaBuffer = Marshal.StringToHGlobalUni(privilegeName);
         lsaUserRights[0].lsaLength = (ushort)(privilegeName.Length * 2);
         lsaUserRights[0].lsaMaximumLength = (ushort)((privilegeName.Length + 1) * 2);
         SecurityIdentifier sid = new SecurityIdentifier(sidString);
         byte[] numArray = new byte[sid.BinaryLength];
         sid.GetBinaryForm(numArray, 0);
         IntPtr num2 = Marshal.AllocHGlobal(sid.BinaryLength);
         Marshal.Copy(numArray, 0, num2, sid.BinaryLength);
         try
         {
             ntStatus = LsaNtStatusToWinError(LsaAddAccountRights(lsaPolicyHandle, num2, lsaUserRights, 1L));
             if (ntStatus != 0)
             {
                 Console.WriteLine("LsaAddAccountRights failed: " + ntStatus);
             }
             else
             {
                 Console.WriteLine("LsaAddAccountRights succeeded");
             }
             LsaClose(lsaPolicyHandle);
         }
         finally
         {
             Marshal.FreeHGlobal(num2);
         }
     }
     return ntStatus;
 }
 private struct LSA_UNICODE_STRING
 {
     public ushort lsaLength;
     public ushort lsaMaximumLength;
     public IntPtr lsaBuffer;
 }
 private struct LSA_OBJECT_ATTRIBUTES
 {
     public int Length;
     public IntPtr RootDirectory;
     public LSA_UNICODE_STRING ObjectName;
     public uint Attributes;
     public IntPtr SecurityDescriptor;
     public IntPtr SecurityQualityOfService;
 }
}
'@
        $userSid = (New-Object System.Security.Principal.NTAccount($username)).Translate([System.Security.Principal.SecurityIdentifier]).value
        [LsaUtility]::AddPrivilege($userSid, "SeServiceLogonRight")
    
        
    }
    else {
        Write-Host "Пользователь уже существует" -ForegroundColor Red -BackgroundColor Black
     }
      
     [PSCustomObject]@{
        Name = $username

    }
    
}