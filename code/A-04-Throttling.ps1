# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

#region C# Code: Throttling
$source = @'
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;

namespace Freds.Questionable
{
	/// <summary>
    /// Base implementation of a throttling handler
    /// </summary>
    public abstract class ThrottleBase
    {
        /// <summary>
        /// This should only return when the next execution can happen
        /// </summary>
        /// <param name="Timeout">Maximum time to wait. Throw an exception if expires before next slot becomes available</param>
        public abstract void GetSlot(TimeSpan Timeout);

		/// <summary>
        /// This should only return when the next execution can happen
        /// </summary>
        public abstract void GetSlot();

        /// <summary>
        /// Any cleanup action to take without resetting the throttle.
        /// </summary>
        public abstract void Purge();

        /// <summary>
        /// Reset the full throttling condition to base.
        /// </summary>
        public abstract void Reset();
    }

	/// <summary>
    /// A throttling condition, limiting to X calls per y time.
    /// </summary>
    public class ThrottleSet : ThrottleBase
    {
        /// <summary>
        /// The maximum number of slots per interval
        /// </summary>
        public int Limit;

        /// <summary>
        /// The interval over which slots are limited
        /// </summary>
        public TimeSpan Interval;

        /// <summary>
        /// The number of slots currently taken
        /// </summary>
        public int Count { get { return slots.Count; } }

        private ConcurrentQueue<DateTime> slots = new ConcurrentQueue<DateTime>();

        /// <summary>
        /// Create a new throttle object
        /// </summary>
        /// <param name="Limit">How many slots are available per interval?</param>
        /// <param name="Interval">hat is the interval over which slots are measured?</param>
        public ThrottleSet(int Limit, TimeSpan Interval)
        {
            this.Limit = Limit;
            this.Interval = Interval;
        }

        /// <summary>
        /// Obtain an execution slots from the throttle
        /// </summary>
        /// <param name="Timeout">How long are you willing to wait for a slot before giving up?</param>
        public override void GetSlot(TimeSpan Timeout)
        {
            if (slots.Count < Limit)
            {
                slots.Enqueue(DateTime.Now);
                return;
            }

            DateTime start = DateTime.Now;
            while (true)
            {
                Purge();

                if (slots.Count < Limit)
                    break;

                if (Timeout != null && start.Add(Timeout) < DateTime.Now)
                    throw new TimeoutException("Waiting too long for a slot");

                System.Threading.Thread.Sleep(250);
            }

            slots.Enqueue(DateTime.Now);
        }

		/// <summary>
        /// Obtain an execution slots from the throttle
        /// </summary>
        public override void GetSlot()
        {
            if (slots.Count < Limit)
            {
                slots.Enqueue(DateTime.Now);
                return;
            }

            DateTime start = DateTime.Now;
            while (true)
            {
                Purge();

                if (slots.Count < Limit)
                    break;

                System.Threading.Thread.Sleep(250);
            }

            slots.Enqueue(DateTime.Now);
        }

        /// <summary>
        /// Clean up any expired slots
        /// </summary>
        public override void Purge()
        {
            DateTime last;
            slots.TryPeek(out last);
            while (last.Add(Interval) < DateTime.Now && slots.Count > 0)
            {
                slots.TryDequeue(out last);
                slots.TryPeek(out last);
            }
        }

        /// <summary>
        /// Resets the throttling conditions, restoring all available slots
        /// </summary>
        public override void Reset()
        {
            slots = new ConcurrentQueue<DateTime>();
        }
    }

	/// <summary>
    /// A throttle limit based on "Not Before" a certain timestamp
    /// </summary>
    public class ThrottleTime : ThrottleBase
    {
        /// <summary>
        /// The time limit: No execution before this time should occur
        /// </summary>
        public DateTime NotBefore;

        /// <summary>
        /// The parent throttle object
        /// </summary>
        public Throttle Parent;

        /// <summary>
        /// Creates a new throttle condition object, preventing the execution before the specified time
        /// </summary>
        /// <param name="notBefore">The timestamp until which we shall wait</param>
        /// <param name="parent">The throttle object</param>
        public ThrottleTime(DateTime notBefore, Throttle parent)
        {
            NotBefore = notBefore;
            Parent = parent;
        }

        /// <summary>
        /// Take a chill pill until the time limit is over
        /// </summary>
        /// <param name="Timeout">Maximum time we are willing to wait. Will error right away, if the time limit is longer.</param>
        /// <exception cref="TimeoutException">Won't return before the timeout</exception>
        public override void GetSlot(TimeSpan Timeout)
        {
            if (Timeout != null && DateTime.Now.Add(Timeout) < NotBefore)
                throw new TimeoutException($"The timeout {Timeout} will expire before the time blocker {NotBefore} has passed!");

            System.Threading.Thread.Sleep(NotBefore - DateTime.Now);
            Reset();
        }

		/// <summary>
        /// Take a chill pill until the time limit is over
        /// </summary>
        public override void GetSlot()
        {
            System.Threading.Thread.Sleep(NotBefore - DateTime.Now);
            Reset();
        }

        /// <summary>
        /// Do nothing
        /// </summary>
        public override void Purge()
        {
            // Nothing happens here
        }

        /// <summary>
        /// Disables the limit
        /// </summary>
        public override void Reset()
        {
            NotBefore = DateTime.MinValue;
            if (null == Parent)
                return;

            KeyValuePair<Guid, ThrottleBase> key = Parent._Throttles.Where(o => o.Value == this).First();
            if (key.Key != null)
                Parent._Throttles.TryRemove(key.Key, out _);
        }
    }

	/// <summary>
    /// Class implementing a throttling mechanism / watcher
    /// </summary>
    public class Throttle
    {
        internal ConcurrentDictionary<Guid,ThrottleBase> _Throttles = new ConcurrentDictionary<Guid, ThrottleBase>();

        /// <summary>
        /// All throttling limits
        /// </summary>
        public ThrottleBase[] Limits => _Throttles.Values.ToArray();

        /// <summary>
        /// The maximum number of slots per interval
        /// </summary>
        public int Limit
        {
            get
            {
                ThrottleBase first = _Throttles.Values.Where(o => o.GetType() == typeof(ThrottleSet)).First();
                if (first != null)
                    return ((ThrottleSet)first).Limit;
                return 0;
            }
            set
            {
                ThrottleBase first = _Throttles.Values.Where(o => o.GetType() == typeof(ThrottleSet)).First();
                if (first != null)
                    ((ThrottleSet)first).Limit = value;
                else
                    _Throttles[Guid.NewGuid()] = new ThrottleSet(value, new TimeSpan(0, 0, 0));
            }
        }

        /// <summary>
        /// The interval over which slots are limited
        /// </summary>
        public TimeSpan Interval
        {
            get
            {
                ThrottleBase first = _Throttles.Values.Where(o => o.GetType() == typeof(ThrottleSet)).First();
                if (first != null)
                    return ((ThrottleSet)first).Interval;
                return new TimeSpan(0, 0, 0);
            }
            set
            {
                ThrottleBase first = _Throttles.Values.Where(o => o.GetType() == typeof(ThrottleSet)).First();
                if (first != null)
                    ((ThrottleSet)first).Interval = value;
                else
                    _Throttles[Guid.NewGuid()] = new ThrottleSet(1, value);
            }
        }

        /// <summary>
        /// The number of slots currently taken
        /// </summary>
        public int Count
        {
            get
            {
                ThrottleBase first = _Throttles.Values.Where(o => o.GetType() == typeof(ThrottleSet)).First();
                if (first == null)
                    return 0;
                return ((ThrottleSet)first).Count;
            }
        }

        /// <summary>
        /// DO not grant a slot before this timestamp has been reached.
        /// </summary>
        public DateTime NotBefore
        {
            get
            {
                ThrottleBase longest = _Throttles.Values.Where(o => o.GetType() == typeof(ThrottleTime)).OrderByDescending(o => ((ThrottleTime)o).NotBefore).First();
                if (longest != null)
                    return ((ThrottleTime)longest).NotBefore;
                return DateTime.MinValue;
            }
            set => _Throttles[Guid.NewGuid()] = new ThrottleTime(value, this);
        }

        /// <summary>
        /// Create a new throttle object
        /// </summary>
        public Throttle()
        {

        }

        /// <summary>
        /// Create a new throttle object
        /// </summary>
        /// <param name="Limit">How many slots are available per interval?</param>
        /// <param name="Interval">hat is the interval over which slots are measured?</param>
        public Throttle(int Limit, TimeSpan Interval)
        {
            _Throttles[Guid.NewGuid()] = new ThrottleSet(Limit, Interval);
        }

        /// <summary>
        /// Obtain an execution slots from the throttle
        /// </summary>
        /// <param name="Timeout">How long are you willing to wait for a slot before giving up?</param>
        public void GetSlot(TimeSpan Timeout)
        {
            foreach (ThrottleBase entry in _Throttles.Values)
                entry.GetSlot(Timeout);
        }

		public void GetSlot()
		{
			foreach (ThrottleBase entry in _Throttles.Values)
                entry.GetSlot();
		}

        /// <summary>
        /// Clean up all throttle sets
        /// </summary>
        public void Purge()
        {
            foreach (ThrottleBase entry in _Throttles.Values)
                entry.Purge();
        }

        /// <summary>
        /// Resets all throttling limits
        /// </summary>
        public void Reset()
        {
            foreach (ThrottleBase entry in _Throttles.Values)
                entry.Reset();
        }

        /// <summary>
        /// Removes a limit from the throttle
        /// </summary>
        /// <param name="Limit">The limit to remove</param>
        public void RemoveLimit(ThrottleBase Limit)
        {
            KeyValuePair<Guid, ThrottleBase> key = _Throttles.Where(o => o.Value == Limit).First();
            if (key.Key != null)
                _Throttles.TryRemove(key.Key, out _);
        }

        /// <summary>
        /// Add a limit to the throttle
        /// </summary>
        /// <param name="Limit">A pre-created limit to add</param>
        public void AddLimit(ThrottleBase Limit)
        {
            _Throttles[Guid.NewGuid()] = Limit;
        }

        /// <summary>
        /// Add a throttle control, limiting executions within a given timespan
        /// </summary>
        /// <param name="Interval">The timespan within which executions are counted</param>
        /// <param name="Count">The number of action slots within the specified interval</param>
        public void AddLimit(TimeSpan Interval, int Count)
        {
            _Throttles[Guid.NewGuid()] = new ThrottleSet(Count, Interval);
        }

        /// <summary>
        /// Add a throttle control, blocking any further executions until the specified time has come to pass.
        /// </summary>
        /// <param name="Timeout">Time until when no further action should take place</param>
        public void AddLimit(DateTime Timeout)
        {
            _Throttles[Guid.NewGuid()] = new ThrottleTime(Timeout, this);
        }
    }
}
'@
Add-Type $source
#endregion C# Code: Throttling

# Quick and simple
$throttle = [Freds.Questionable.Throttle]::new()
$throttle.AddLimit('00:00:10', 3)
$throttle.GetSlot()

$throttle.AddLimit('00:00:05', 2)
$throttle.GetSlot()

$throttle.NotBefore = (Get-Date).AddSeconds(5)
$throttle.GetSlot()

$param = @{
	Variables = @{
		throttle = $throttle
	}
	Throttle = 4
	Wait = $true
}

1..7 | Invoke-Runspace @param -Scriptblock {
	param ($Value)
	$datum = [PSCustomObject]@{
		Value = $Value
		Start = Get-Date
		End = $null
	}
	$throttle.GetSlot()
	$datum.End = Get-Date
	$datum
}

# Continue: Next
code "$presentationRoot\A-05-PerRunspaceValue.ps1"
# Continue: Runspace Workflows
code "$presentationRoot\B-01-RunspaceWorkflows.ps1"