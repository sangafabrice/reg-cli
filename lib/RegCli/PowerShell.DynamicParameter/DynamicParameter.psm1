#Requires -Version 7.0
#Requires -RunAsAdministrator
using namespace 'System.Management.Automation'

Class DynamicParameter {
    # Creates a dynamic parameter and is called in DynamicParam block in a function definition.

    Static [RuntimeDefinedParameterDictionary] Create([string] $ParameterName, [System.Reflection.TypeInfo] $ParameterType) {
        # Returns a non-mandatory dynamic parameter with a specified type.

        $AttribCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::New()
        $AttribCollection.Add([ParameterAttribute] @{ Mandatory = $False })
        $ParamDictionary = [RuntimeDefinedParameterDictionary]::New()
        $ParamDictionary.Add($ParameterName,[RuntimeDefinedParameter]::New($ParameterName, $ParameterType, $AttribCollection))
        Return $ParamDictionary
    }
}