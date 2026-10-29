Public Class Greeter
    Public Sub New(name As String)
        _name = name
    End Sub

    ''' <summary>Says hi.</summary>
    Public Function Greet() As String
        Return "Hi " & _name
    End Function

    Private Shared Sub Log(msg As String)
    End Sub
End Class
