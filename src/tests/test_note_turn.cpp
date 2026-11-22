#include <gtest/gtest.h>

#include "NoteData.h"
#include "NoteDataUtil.h"
#include "NoteTypes.h"

TEST(NoteTurn, ChartTapFollowsComposedTurnsOnDoubles) {
  NoteData data;
  data.SetNumTracks(8);
  data.SetTapNote(7, 48, TAP_ORIGINAL_TAP);
  data.SetTapNote(0, 48, TAP_ORIGINAL_MINE);
  EXPECT_EQ(data.GetTrackForChartTap(7, 48), 7);
  EXPECT_EQ(data.GetTrackForChartTap(0, 48), -1);

  NoteDataUtil::Turn(data, StepsType_dance_double, NoteDataUtil::mirror);
  EXPECT_EQ(data.GetTrackForChartTap(7, 48), 0);
  NoteDataUtil::Turn(data, StepsType_dance_double, NoteDataUtil::mirror);
  EXPECT_EQ(data.GetTrackForChartTap(7, 48), 7);
  EXPECT_EQ(data.GetTrackForChartTap(0, 48), -1);
  EXPECT_EQ(data.GetTrackForChartTap(7, 49), -1);
}

TEST(NoteTurn, ChartTapsFollowIndividualRowsThroughHyperShuffle) {
  NoteData data;
  data.SetNumTracks(4);
  // Keysounds identify the two taps independently of their runtime columns.
  for (int row = 48; row <= 144; row += 48) {
    for (int col : {0, 3}) {
      TapNote tap = TAP_ORIGINAL_TAP;
      tap.keysound_index_ = col;
      data.SetTapNote(col, row, tap);
    }
  }
  NoteDataUtil::Turn(data, StepsType_dance_single, NoteDataUtil::left);
  NoteDataUtil::Turn(data, StepsType_dance_single, NoteDataUtil::hyper_shuffle);
  for (int row = 48; row <= 144; row += 48) {
    for (int col : {0, 3}) {
      int dest = data.GetTrackForChartTap(col, row);
      ASSERT_GE(dest, 0);
      EXPECT_EQ(data.GetTapNote(dest, row).keysound_index_, col);
    }
  }
}
