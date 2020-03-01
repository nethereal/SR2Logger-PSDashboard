Class Spacecraft 
{
    [hashtable]$state 
    [hashtable]$history
    [array]$listeners

    Spacecraft(){
        $this.state = @{
            ActivationGroup1 = 0
            ...
        }
        $this.history = @{
            ActivationGroup1 = @()
            ...
        }

        #TODO: "setInterval" - run updateState and generateTelemetry methods on an interval
        ### this is a timed update/grab from synchronized hashtable
        #### TOREVIEW as this is likely already done with the sr2logger ps script
    }

    updateState () {
        #TODO: runspace data grab here.
    }

    generateTelemetry () {
        #get $timestamp in unix time
        $utctimestamp = [int][double]::Parse((Get-Date -UFormat %s))
        #Must substitute for game time value in future
        ForEach ($key in $this.state.Keys) {
            [hashtable]$tmphash = @{
                timestamp = $utctimestamp
                value = $this.state.$key.value
                id = $key
            }
            $this.notify($tmphash)
            $this.history.$key = $this.history.$key + $tmphash
        }
    }

    notify ($point) {
        ForEach ($listener in $this.listeners) { 
            #$listener($point)
            #need to explore other classes further
        }
    }

    listen ($listener) {
        $this.listeners = $this.listeners + $listener
        #TODO: some weird return
    }

}
$spacecrafttemp = [Spacecraft]::new()
$spacecrafttemp.state = [hashtable]::Synchronized($spacecrafttemp.state)
$spacecrafttemp.history = [hashtable]::Synchronized($spacecrafttemp.history)

return $spacecrafttemp