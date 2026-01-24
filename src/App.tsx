import { useEffect, useState } from 'react';
import { Box } from './components/Box';
import { getOrCreateSession, makePick } from './lib/sessionManager';
import { PickSession } from './lib/supabase';
import { Sparkles } from 'lucide-react';

function App() {
  const [session, setSession] = useState<PickSession | null>(null);
  const [loading, setLoading] = useState(true);
  const [picking, setPicking] = useState(false);
  const [showConfetti, setShowConfetti] = useState(false);

  useEffect(() => {
    loadSession();
  }, []);

  async function loadSession() {
    try {
      const sessionData = await getOrCreateSession();
      setSession(sessionData);

      if (sessionData.picked_index !== null) {
        setShowConfetti(true);
      }
    } catch (error) {
      console.error('Failed to load session:', error);
    } finally {
      setLoading(false);
    }
  }

  async function handlePick(index: number) {
    if (!session || picking || session.picked_index !== null) return;

    setPicking(true);
    try {
      const updatedSession = await makePick(index, session);
      setSession(updatedSession);
      setShowConfetti(true);
    } catch (error) {
      console.error('Failed to make pick:', error);
    } finally {
      setPicking(false);
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900 flex items-center justify-center">
        <div className="text-white text-xl animate-pulse">Loading...</div>
      </div>
    );
  }

  const hasPicked = session?.picked_index !== null;
  const totalBoxes = session?.total_boxes || 0;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900 py-12 px-4">
      {showConfetti && (
        <div className="fixed inset-0 pointer-events-none z-50">
          <div className="absolute inset-0 animate-confetti">
            {[...Array(50)].map((_, i) => (
              <div
                key={i}
                className="absolute w-2 h-2 bg-yellow-400 rounded-full animate-fall"
                style={{
                  left: `${Math.random() * 100}%`,
                  animationDelay: `${Math.random() * 2}s`,
                  animationDuration: `${2 + Math.random() * 2}s`
                }}
              />
            ))}
          </div>
        </div>
      )}

      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-12">
          <div className="flex items-center justify-center gap-3 mb-4">
            <Sparkles className="w-10 h-10 text-yellow-400" />
            <h1 className="text-5xl font-bold text-white">Pick One Box</h1>
            <Sparkles className="w-10 h-10 text-yellow-400" />
          </div>

          {!hasPicked ? (
            <p className="text-xl text-blue-200 max-w-2xl mx-auto">
              Choose one box. You only get one chance.
            </p>
          ) : (
            <div className="mt-6 space-y-2">
              <div className="text-3xl font-bold text-green-400 animate-bounce">
                🎉 You picked:
              </div>
              <div className="text-4xl font-bold text-white mt-2">
                {session?.picked_name}
              </div>
              <p className="text-blue-200 mt-4 text-lg">
                Picking ended. You had one chance.
              </p>
            </div>
          )}
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4 md:gap-6 max-w-5xl mx-auto">
          {Array.from({ length: totalBoxes }).map((_, index) => (
            <Box
              key={index}
              index={index}
              isRevealed={hasPicked}
              isPicked={session?.picked_index === index}
              isDisabled={picking || hasPicked}
              revealedName={session?.picked_index === index ? (session?.picked_name ?? undefined) : undefined}
              onClick={() => handlePick(index)}
            />
          ))}
        </div>

        {!hasPicked && (
          <div className="mt-12 text-center">
            <p className="text-blue-300 text-sm">
              {totalBoxes} boxes • 1 chance • Choose wisely
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
