import { Gift } from 'lucide-react';

interface BoxProps {
  index: number;
  isRevealed: boolean;
  isPicked: boolean;
  isDisabled: boolean;
  revealedName?: string;
  onClick: () => void;
}

export function Box({ index, isRevealed, isPicked, isDisabled, revealedName, onClick }: BoxProps) {
  return (
    <button
      onClick={onClick}
      disabled={isDisabled}
      className={`
        relative aspect-square rounded-2xl shadow-lg transition-all duration-500
        flex items-center justify-center group
        ${!isRevealed && !isDisabled ? 'hover:scale-105 hover:shadow-xl cursor-pointer' : ''}
        ${isDisabled && !isRevealed ? 'cursor-not-allowed opacity-40' : ''}
        ${!isRevealed ? 'bg-gradient-to-br from-blue-500 to-blue-600' : ''}
        ${isRevealed && isPicked ? 'bg-gradient-to-br from-green-500 to-emerald-600 scale-105' : ''}
        ${isRevealed && !isPicked ? 'bg-gradient-to-br from-gray-400 to-gray-500' : ''}
      `}
    >
      {!isRevealed ? (
        <div className="flex flex-col items-center gap-2">
          <Gift className="w-12 h-12 text-white/90 group-hover:scale-110 transition-transform" />
          <span className="text-white/70 text-sm font-medium">Box {index + 1}</span>
        </div>
      ) : (
        <div className="p-4 text-center animate-fadeIn">
          {isPicked ? (
            <>
              <div className="text-4xl mb-2">🎉</div>
              <div className="text-white font-bold text-lg break-words">
                {revealedName}
              </div>
            </>
          ) : (
            <div className="text-white/50 text-sm">Not Picked</div>
          )}
        </div>
      )}
    </button>
  );
}
