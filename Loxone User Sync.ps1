# Definieren des Zeitintervalls in Sekunden
$Zeitintervall = 10 # Beispiel für 1 Stunde = 3600

# Pfad zur Log-Datei
$logPfad = "C:\Loxone-User-Management\User-Management.log"

# Pfad zur Export-CSV-Datei
$exportADCsvPfad = "C:\Loxone-User-Management\ExportAD.csv"

# Pfad zur Export-CSV-Datei
$exportLoxoneCsvPfad = "C:\Loxone-User-Management\ExportLoxone.csv"


# Variablen definieren Loxone Server
$LoxoneAdminUser = "Experte"
$LoxoneAdminPasswort = "Experte1234"
$LoxoneIPAdresse = "10.10.129.100"

#_________________________________________________________________________________________________________

echo ">>====================================================<<";
echo "||██╗      ██████╗ ██╗  ██╗ ██████╗ ███╗   ██╗███████╗||";
echo "||██║     ██╔═══██╗╚██╗██╔╝██╔═══██╗████╗  ██║██╔════╝||";
echo "||██║     ██║   ██║ ╚███╔╝ ██║   ██║██╔██╗ ██║█████╗  ||";
echo "||██║     ██║   ██║ ██╔██╗ ██║   ██║██║╚██╗██║██╔══╝  ||";
echo "||███████╗╚██████╔╝██╔╝ ██╗╚██████╔╝██║ ╚████║███████╗||";
echo "||╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝||";
echo "||██████╗ ██╗   ██╗    ███╗   ███╗███████╗            ||";
echo "||██╔══██╗╚██╗ ██╔╝    ████╗ ████║██╔════╝            ||";
echo "||██████╔╝ ╚████╔╝     ██╔████╔██║███████╗            ||";
echo "||██╔══██╗  ╚██╔╝      ██║╚██╔╝██║╚════██║            ||";
echo "||██████╔╝   ██║       ██║ ╚═╝ ██║███████║            ||";
echo "||╚═════╝    ╚═╝       ╚═╝     ╚═╝╚══════╝            ||";
echo ">>====================================================<<";



# Extrahieren des Ordnerpfades aus dem Export-CSV-Pfad
$ordnerPfad = [System.IO.Path]::GetDirectoryName($exportADCsvPfad)

# Überprüfen, ob der Ordner existiert, wenn nicht, erstellen
If (!(Test-Path -Path $ordnerPfad)) {
    New-Item -ItemType Directory -Force -Path $ordnerPfad
}

# Dauerschleife
while ($true) {
    try {
        # Speichern des Startdatums und der Startzeit
        $startDatumZeit = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Suche nach der Gruppe 'Loxone'
        $gruppenMitglieder = Get-ADGroupMember -Identity "Loxone" -ErrorAction Stop | Get-ADUser -Property Enabled -ErrorAction Stop

        # Initialisieren des Arrays für die Benutzerprinzipalnamen und deren Aktivierungsstatus
        $benutzerArray = @()
        $exportArray = @()

        # Hinzufügen der Benutzerprinzipalnamen und deren Aktivierungsstatus zum Array
        foreach ($mitglied in $gruppenMitglieder) {
            # Prüfen, ob der Benutzer aktiviert oder deaktiviert ist und den entsprechenden Status als String zuweisen
            $status = if ($mitglied.Enabled) {"0"} else {"1"}
            
            # Korrekte Formatierung der Benutzerinformationen für das Array
            $benutzerInfo = "`"$($mitglied.UserPrincipalName)`",`"$status`""
            $benutzerArray += $benutzerInfo

            # Für die CSV-Datei vorbereiten
            $exportObjekt = New-Object PSObject -Property @{
                UserPrincipalName = $mitglied.UserPrincipalName
                Status = $status
            }
            $exportArray += $exportObjekt
        }

        # Erstellen der zu loggenden Zeichenkette
        $benutzerString = $benutzerArray -join ";"
        $logEintrag = "Startdatum und -zeit: $startDatumZeit`r`nBenutzer: [$benutzerString]`r`n"

        # Schreiben der Daten in die Log-Datei
        Add-Content -Path $logPfad -Value $logEintrag

        # Exportieren der Benutzerdaten in die CSV-Datei, überschreibt die Datei bei jedem Durchlauf
        $exportArray | Select-Object UserPrincipalName, Status | Export-Csv -Path $exportADCsvPfad -NoTypeInformation -Encoding UTF8
    }
    catch {
        # Fehlermeldung in die Log-Datei schreiben
        Add-Content -Path $logPfad -Value "Ein Fehler ist aufgetreten: $_`r`n"
    }

    # CSV-Datei einlesen, Kopfzeile überspringen, wenn vorhanden
    $csvDatenAD = Import-Csv -Path $exportADCsvPfad
    # Durch jede Zeile der CSV-Datei iterieren
    foreach ($zeile in $csvDatenAD) {
        # Benutzername und Status extrahieren
        $username = $zeile.UserPrincipalName
        $status = $zeile.Status
    }

    # URL dynamisch zusammenbauen
    $urlGetUser = "http://${LoxoneIPAdresse}/jdev/sps/getuserlist2"

    # Base64-Encodierung der Anmeldedaten
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${LoxoneAdminUser}:${LoxoneAdminPasswort}"))

    # Erstellen des Headers für die Anfrage
    $headers = @{
        "Authorization" = "Basic $base64AuthInfo"
    }

    # Durchführen des API-Aufrufs
    try {
        $response = Invoke-WebRequest -Uri $urlGetUser -Headers $headers
        Add-Content -Path $logPfad -Value $response.Content
    } catch {
        Add-Content -Path $logPfad -Value "Fehler: $($_.Exception.Response.StatusCode.Value__) $_.Exception.Message"
    }
    
    # JSON-Antwort in ein Objekt konvertieren
    $responseObj = $response | ConvertFrom-Json

    # Zugriff auf den 'value'-Teil der Antwort und Konvertierung von JSON in ein PowerShell-Objekt
    $users = $responseObj.LL.value | ConvertFrom-Json

    # Exportieren der Benutzerdaten in eine CSV-Datei
    $users | Export-Csv -Path $exportLoxoneCsvPfad -NoTypeInformation -Encoding UTF8

    # CSV-Datei einlesen
    $csvDatenLox = Import-Csv -Path $exportLoxoneCsvPfad

    # Array für gespeicherte Daten initialisieren
    $LoxUser = @()
    $uuid = @()
    $LoxUserState = @()

    # Durch jede Zeile der CSV-Datei iterieren
    foreach ($zeile in $csvDatenLox) {
        # Werte in entsprechenden Arrays speichern
        $LoxUser += $zeile.name
        $uuid += $zeile.uuid
        $LoxUserState += $zeile.userState
        }

    # Initialisieren der Array-Variable für neue Loxone-Benutzer
    $newLoxUser = @()

    # Benutzer aus AD-CSV durchgehen
    foreach ($adBenutzer in $csvDatenAD) {
        $username = $adBenutzer.UserPrincipalName
        $status = $adBenutzer.Status

        # Überprüfen, ob der Benutzer im Loxone CSV vorhanden ist
        $loxoneBenutzer = $csvDatenLox | Where-Object { $_.name -eq $username }

        if ($null -eq $loxoneBenutzer) {
        # Benutzer nicht in Loxone vorhanden, zum Array hinzufügen
            $newLoxUser += $adBenutzer
        } else {
            # Benutzer vorhanden, Status überprüfen und gegebenenfalls anpassen
            if ($loxoneBenutzer.userState -ne $status) {
                # Status in Loxone-CSV-Daten aktualisieren
                $loxoneBenutzer.userState = $status
                $uuid = $loxoneBenutzer.uuid
                # Änderung in Log-Datei schreiben
                $logEintrag = "Statusänderung für Benutzer $username zu $status am $startDatumZeit"
                Add-Content -Path $logPfad -Value $logEintrag

                # Änderung des Benutzers im Miniserver
                $urlChangeUserStatus = "http://${LoxoneIPAdresse}/jdev/sps/addoredituser/{`"name`":`"$username`",`"uuid`":`"$uuid`",`"userState`":$status}"
                # API-Aufruf zur Änderung des Benutzerstatus
                try {
                    $response = Invoke-WebRequest -Uri $urlChangeUserStatus -Headers $headers -Method Get
                    $logEintrag = "Status für Benutzer $username zu $status geändert. Antwort: $($response.Content)"
                    Add-Content -Path $logPfad -Value $logEintrag
                } catch {
                    $errorLog = "Fehler beim Ändern des Status für Benutzer ${username}: $($_.Exception.Message)"
                    Add-Content -Path $logPfad -Value $errorLog
                }
            }
        }
    }

    # Neue Benutzer, die in Loxone hinzugefügt werden müssen, ausgeben
    foreach ($user in $newLoxUser) {
        Add-Content -Path $logPfad -Value "Neuer Loxone Benutzer: $($user.UserPrincipalName) mit Status: $($user.Status)"
        # Hier der Code zum  hinzufügen des Benutzers in Loxone 
        # URL dynamisch zusammenbauen
        $urlCreateUser = "http://${LoxoneIPAdresse}/jdev/sps/addoredituser/{`"name`":`"$($user.UserPrincipalName)`",`"changePassword`":true,`"userState`":`"$($user.Status)`"}"

         # Durchführen des API-Aufrufs
        try {
            $responseLox = Invoke-WebRequest -Uri $urlCreateUser -Headers $headers
            Add-Content -Path $logPfad -Value $responseLox.Content
        } catch {
            Add-Content -Path $logPfad -Value "Fehler: $($_.Exception.Response.StatusCode.Value__) $_.Exception.Message"
        }
    }

    # Geänderte Loxone Benutzerdaten zurück in die CSV schreiben, wenn nötig
    # Hinweis: Dieser Schritt würde überschreiben oder aktualisieren, wie benötigt.
    $csvDatenLox | Export-Csv -Path $exportLoxoneCsvPfad -NoTypeInformation -Encoding UTF8


    # Warten für das definierte Zeitintervall
    Start-Sleep -Seconds $Zeitintervall

}